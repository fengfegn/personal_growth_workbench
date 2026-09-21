import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/courses/data/course_repository.dart';
import 'package:personal_growth_workbench/features/courses/presentation/course_import_guide_dialog.dart';
import 'package:personal_growth_workbench/features/courses/presentation/courses_page.dart';

void main() {
  testWidgets('renders the weekly course grid and opens session notes', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final monday = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final date =
        '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    await CourseRepository(database).createSession(
      courseName: '人工智能导论',
      date: date,
      startTime: '08:30',
      endTime: '10:05',
      slotStart: 1,
      slotEnd: 2,
      note: '带实验报告',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CoursesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课程安排'), findsOneWidget);
    expect(find.text('人工智能导论'), findsOneWidget);
    expect(find.text('1-2'), findsOneWidget);
    await tester.tap(find.text('人工智能导论'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-note-field')), findsOneWidget);
    expect(find.text('带实验报告'), findsOneWidget);
  });

  testWidgets('shows copyable conversion prompts for course import', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CourseImportGuideDialog()));

    expect(find.text('JSON 版'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data?.contains('courses 和 sessions') == true,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('course-copy-prompt')), findsOneWidget);

    await tester.tap(find.text('Markdown 版'));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data?.contains('原始 Markdown 表格') == true,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data?.contains('courses 和 sessions') == true,
      ),
      findsNothing,
    );
  });

  testWidgets('opens the conversion guide from the import menu', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: CoursesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入课程表'));
    await tester.pumpAndSettle();

    expect(find.text('先用 AI 整理课表'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('course-select-import-file')),
      findsOneWidget,
    );
    await tester.tap(find.text('稍后导入'));
  });
}
