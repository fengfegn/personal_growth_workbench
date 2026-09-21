import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/app/app.dart';
import 'package:personal_growth_workbench/app/theme/app_theme.dart';
import 'package:personal_growth_workbench/app/theme/theme_controller.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/dashboard/presentation/dashboard_page.dart';
import 'package:personal_growth_workbench/features/calendar/data/calendar_event_repository.dart';
import 'package:personal_growth_workbench/features/calendar/domain/calendar_event.dart';
import 'package:personal_growth_workbench/features/goals/data/goal_repository.dart';
import 'package:personal_growth_workbench/features/goals/domain/goal.dart';
import 'package:personal_growth_workbench/features/goals/presentation/goal_page.dart';
import 'package:personal_growth_workbench/features/settings/presentation/settings_page.dart';
import 'package:personal_growth_workbench/features/tasks/domain/task.dart';
import 'package:personal_growth_workbench/features/workbench/application/workbench_providers.dart';

void main() {
  test('fills empty dashboard priority slots with scheduled tasks', () {
    final task = TaskItem(
      id: 'task-1',
      title: 'First task',
      status: TaskStatus.todo,
      priority: 0,
      scheduledDate: '2026-08-05',
      createdAt: DateTime(2026, 8, 5),
      updatedAt: DateTime(2026, 8, 5),
    );
    final dashboard = DashboardData(
      nickname: 'Test',
      tasks: [task],
      topTasks: const [],
      goals: const [],
    );

    expect(dashboard.topTaskBySlot[1]?.id, task.id);
  });

  testWidgets('shows a newly created task on home before priority selection', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(1200, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const PersonalGrowthApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'New task');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
  });

  testWidgets('creates a goal and adds a milestone', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: GoalPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, '新建目标'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Build a thesis');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('Build a thesis'), findsOneWidget);
    expect(find.text('里程碑'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_task));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Proposal approved',
    );
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('Proposal approved'), findsOneWidget);
  });

  testWidgets('shows a saved goal on the home dashboard', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await GoalRepository(database).createGoal(
      title: 'Thesis goal',
      type: GoalType.longTerm,
      targetDate: '2027-06-30',
      progress: 40,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: DashboardHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thesis goal'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('shows the nearest calendar event countdown on home', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await CalendarEventRepository(database).createEvent(
      title: '结婚纪念日',
      type: CalendarEventType.anniversary,
      eventDate: '2026-08-24',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: DashboardHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('结婚纪念日'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-calendar-countdown')),
      findsOneWidget,
    );
  });

  testWidgets('uses desktop navigation at the minimum supported width', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(1024, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const PersonalGrowthApp(),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('今天先完成最重要的三件事。'), findsOneWidget);
  });

  testWidgets('uses a collapsible navigation rail on a desktop layout', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const PersonalGrowthApp(),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byTooltip('收起导航'), findsOneWidget);
    await tester.tap(find.byTooltip('收起导航'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('展开导航'), findsOneWidget);
  });

  testWidgets('shows three empty priority task slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(now: DateTime(2026, 8, 4, 9))),
    );

    expect(find.text('早上好，你的昵称'), findsOneWidget);
    expect(find.text('今天先完成最重要的三件事。'), findsOneWidget);
    expect(find.text('还没有安排事项'), findsNWidgets(3));
  });

  testWidgets('completes the create, top task, home, and completion loop', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(1200, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const PersonalGrowthApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '新建任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '完成本地闭环');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Keep this note visible',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('完成本地闭环'), findsOneWidget);
    expect(find.text('Keep this note visible'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();
    expect(find.text('今日重点 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('完成本地闭环'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('完成本地闭环'), findsOneWidget);
  });

  testWidgets('switches display mode and palette from settings', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const _ThemeHarness(),
      ),
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await tester.tap(find.text(DisplayMode.dark.label));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    final emerald = find.text(ThemePalette.yuan50.label);
    await tester.tap(emerald.last);
    await tester.pump();
    expect(find.text(ThemePalette.yuan50.label), findsWidgets);
  });

  test('restores the selected palette from local settings', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final firstContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    await firstContainer
        .read(themePaletteProvider.notifier)
        .setPalette(ThemePalette.yuan50);
    expect(firstContainer.read(themePaletteProvider), ThemePalette.yuan50);
    firstContainer.dispose();

    final secondContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(secondContainer.dispose);
    await secondContainer.read(themePaletteProvider.notifier).initialized;

    expect(secondContainer.read(themePaletteProvider), ThemePalette.yuan50);
  });
}

class _ThemeHarness extends ConsumerWidget {
  const _ThemeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final mode = ref.watch(displayModeProvider);
    return MaterialApp(
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: mode.themeMode,
      home: const SettingsPage(),
    );
  }
}
