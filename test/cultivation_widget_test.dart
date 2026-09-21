import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/cultivation/application/cultivation_providers.dart';
import 'package:personal_growth_workbench/features/cultivation/data/cultivation_repository.dart';
import 'package:personal_growth_workbench/features/cultivation/domain/cultivation.dart';
import 'package:personal_growth_workbench/features/cultivation/presentation/cultivation_page.dart';

void main() {
  test('centers every non-empty bar group on its date category', () {
    final today = DateTime(2026, 9, 17);
    final summaries = List<DailyCultivationSummary>.generate(
      7,
      (index) => DailyCultivationSummary(
        date: today.subtract(Duration(days: 6 - index)),
        learningSeconds: index == 0 || index == 2 ? 3600 : 0,
        exerciseSeconds: index == 1 || index == 2 ? 1200 : 0,
      ),
    );
    for (final width in [1920.0, 1440.0, 1024.0, 768.0]) {
      final layout = DailyChartLayout.fromSize(Size(width, 218), summaries);

      for (var index = 0; index < summaries.length; index++) {
        final summary = summaries[index];
        final bars = [
          layout.barRect(summary, index, learning: true),
          layout.barRect(summary, index, learning: false),
        ].where((bar) => bar.width > 0).toList();
        if (bars.isEmpty) continue;

        final groupCenter = (bars.first.left + bars.last.right) / 2;
        expect(
          (layout.tickCenterX(index) - layout.barGroupCenterX(index)).abs(),
          lessThanOrEqualTo(1),
          reason: 'tick and group scales differ at width $width',
        );
        expect(
          (groupCenter - layout.barGroupCenterX(index)).abs(),
          lessThanOrEqualTo(1),
          reason: 'category $index is not centered at width $width',
        );
        expect(bars.first.left, greaterThanOrEqualTo(layout.chart.left));
        expect(bars.last.right, lessThanOrEqualTo(layout.chart.right));
      }
    }
  });

  testWidgets('shows the cultivation empty state and creates a technique', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CultivationPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有功法'), findsOneWidget);
    expect(find.text('当前境界'), findsOneWidget);
    expect(find.text('闻弦'), findsWidgets);
    expect(find.text('下一境界：鸣骨'), findsOneWidget);
    expect(find.text('近 7 日修炼'), findsOneWidget);
    expect(find.text('最近修炼'), findsNothing);
    expect(
      find.byKey(const ValueKey('cultivation-daily-chart')),
      findsOneWidget,
    );
    final createButton = find.widgetWithText(FilledButton, '创建第一门功法');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Flutter');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('境界：初识 · 下一阶段 入门'), findsOneWidget);

    final startButton = find.widgetWithText(FloatingActionButton, '开始修炼');
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('开启倒计时'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('倒计时分钟'), findsOneWidget);
    expect(find.text('开始后进入全屏计时'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('adds a duration tooltip to a chart bar', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = CultivationRepository(database);
    final endedAt = DateTime.now().toUtc();
    await repository.finishSession(
      type: CultivationType.learning,
      startedAt: endedAt.subtract(const Duration(hours: 1)),
      endedAt: endedAt,
      durationSeconds: 3600,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CultivationPage()),
      ),
    );
    await tester.pumpAndSettle();

    final tooltip = find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == '学习时长：1小时',
    );
    expect(tooltip, findsOneWidget);
  });
}
