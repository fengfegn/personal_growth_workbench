import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/calendar/presentation/calendar_page.dart';
import 'package:personal_growth_workbench/features/calendar/domain/calendar_holiday.dart';
import 'package:personal_growth_workbench/features/calendar/data/calendar_event_repository.dart';
import 'package:personal_growth_workbench/features/calendar/domain/calendar_event.dart';
import 'package:personal_growth_workbench/features/quick_notes/data/quick_note_repository.dart';
import 'package:personal_growth_workbench/features/quick_notes/domain/quick_note.dart';
import 'package:personal_growth_workbench/features/tasks/data/task_repository.dart';

void main() {
  test('provides local holiday names for the calendar', () {
    final springFestival = CalendarHolidayCatalog.forDate(
      DateTime(2026, 2, 17),
    );

    expect(springFestival?.name, '春节');
    expect(springFestival?.isPublicHoliday, isTrue);
    expect(CalendarHolidayCatalog.forDate(DateTime(2026, 2, 18)), isNull);
  });

  testWidgets('shows a holiday in the selected calendar date', (tester) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CalendarPage(initialDate: DateTime(2026, 2, 17)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('春节'), findsWidgets);
    expect(find.textContaining('法定节日'), findsOneWidget);
  });

  testWidgets('renders a month grid and existing tasks on the selected date', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = TaskRepository(database);
    await repository.createTask(title: '月历中的任务', scheduledDate: '2026-08-15');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CalendarPage(initialDate: DateTime(2026, 8, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8月'), findsOneWidget);
    expect(find.text('2026年'), findsWidgets);
    expect(
      find.byKey(const ValueKey('calendar-day-2026-08-15')),
      findsOneWidget,
    );
    expect(find.text('月历中的任务'), findsWidgets);
    expect(find.text('8月15日'), findsOneWidget);
  });

  testWidgets('uses the selected calendar date when creating a task', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CalendarPage(initialDate: DateTime(2026, 8, 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-08-20')));
    await tester.pump();
    expect(find.text('8月20日'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-create-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '从日期创建的任务');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final tasks = await TaskRepository(
      database,
    ).getActiveTasks(scheduledDate: '2026-08-20');
    expect(tasks.map((task) => task.title), contains('从日期创建的任务'));
  });

  testWidgets('creates a yearly birthday on the selected calendar date', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CalendarPage(initialDate: DateTime(2026, 8, 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-create-event')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('calendar-event-title-field')),
      '妈妈生日',
    );
    await tester.tap(find.byKey(const ValueKey('calendar-event-type-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生日').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-event-save')),
    );
    await tester.tap(find.byKey(const ValueKey('calendar-event-save')));
    await tester.pumpAndSettle();

    final event = (await CalendarEventRepository(database).getEvents()).single;
    expect(event.title, '妈妈生日');
    expect(event.type, CalendarEventType.birthday);
    expect(event.eventDate, '2026-08-20');
    expect(event.repeatsYearly, isTrue);
    expect(find.text('妈妈生日'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-event-count-2026-08-20')),
      findsOneWidget,
    );
  });

  testWidgets('shows and creates quick notes for the selected calendar date', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = QuickNoteRepository(database);
    final tags = await repository.getTags();
    final meetingTag = tags.firstWhere((tag) => tag.name == '会议记录');
    await repository.createNote(
      title: '已有会议记录',
      localDate: '2026-08-15',
      tagIds: [meetingTag.id],
      blocks: const [
        QuickNoteContentBlock(type: QuickNoteBlockType.text, value: '日历中可见'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: CalendarPage(initialDate: DateTime(2026, 8, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已有会议记录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-note-count-2026-08-15')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-08-20')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-create-quick-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-title-field')),
      '从日历创建的记录',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-block-0')),
      '归属选中的日期',
    );
    await tester.tap(find.widgetWithText(FilterChip, '会议记录'));
    await tester.tap(find.byKey(const ValueKey('quick-note-save')));
    await tester.pumpAndSettle();

    final notes = await repository.getNotes(localDate: '2026-08-20');
    expect(notes.single.title, '从日历创建的记录');
    expect(notes.single.tags, ['会议记录']);
    expect(find.text('从日历创建的记录'), findsOneWidget);
  });
}
