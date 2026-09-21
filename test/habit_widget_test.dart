import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/habits/presentation/habit_page.dart';

void main() {
  testWidgets('creates a habit and completes today from the page', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: HabitPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有习惯'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '创建第一个习惯'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '每天阅读');
    await tester.tap(find.widgetWithText(FilledButton, '创建习惯'));
    await tester.pumpAndSettle();

    expect(find.text('每天阅读'), findsWidgets);
    expect(find.text('0 / 1'), findsOneWidget);
    await tester.tap(find.byTooltip('打卡'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('打卡完成，继续保持'), findsOneWidget);
  });
}
