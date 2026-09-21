import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/courses/data/course_repository.dart';
import 'package:personal_growth_workbench/features/courses/data/schedule_parser.dart';

void main() {
  test('parses markdown dates, standard slots, and continuous sessions', () {
    final result = ScheduleParser.parse(
      extension: 'md',
      content: '''
# 第 7 周

| 时间 | 周一 10/12 | 周二 10/13 |
|---|---|---|
| 5-6 13:30-15:05 | 计算机视觉 | - |
| 7-8 15:25-17:00 | ↳ 计算机视觉 | 人工智能导论 |
''',
    );

    expect(result.warnings, isEmpty);
    expect(result.courseCount, 2);
    expect(result.sessionCount, 2);
    final vision = result.sessions.firstWhere(
      (item) => item.courseName == '计算机视觉',
    );
    expect(vision.startTime, '13:30');
    expect(vision.endTime, '17:00');
    expect(vision.slotStart, 5);
    expect(vision.slotEnd, 8);
  });

  test('imports, deduplicates, and reads sessions by week', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = CourseRepository(database);
    final result = ScheduleParser.parse(
      extension: 'json',
      content: '''
{
  "courses": [{"id": "ai", "name": "人工智能导论"}],
  "sessions": [{"courseId": "ai", "date": "2026-10-15", "startTime": "08:30", "endTime": "10:05", "slotStart": 1, "slotEnd": 2, "note": "带报告"}]
}
''',
    );

    final first = await repository.importSchedule(result);
    final second = await repository.importSchedule(result);
    expect(first.createdCourses, 1);
    expect(first.createdSessions, 1);
    expect(second.createdCourses, 0);
    expect(second.createdSessions, 0);

    final week = await repository.getSessionsByWeek(DateTime(2026, 10, 12));
    expect(week.single.courseName, '人工智能导论');
    expect(week.single.note, '带报告');
    expect(await repository.exportJson(), contains('人工智能导论'));
    expect(
      await repository.exportMarkdown(DateTime(2026, 10, 12)),
      contains('人工智能导论'),
    );
  });

  test('reads an xlsx merged cell as one continuous session', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('xl/worksheets/sheet1.xml', '''
<worksheet><sheetData>
<row r="1"><c r="A1" t="inlineStr"><is><t>时间</t></is></c><c r="B1" t="inlineStr"><is><t>周一 10/12</t></is></c></row>
<row r="2"><c r="A2" t="inlineStr"><is><t>5-6 13:30-15:05</t></is></c><c r="B2" t="inlineStr"><is><t>计算机视觉</t></is></c></row>
<row r="3"><c r="A3" t="inlineStr"><is><t>7-8 15:25-17:00</t></is></c></row>
</sheetData><mergeCells count="1"><mergeCell ref="B2:B3"/></mergeCells></worksheet>
'''),
      );
    final bytes = ZipEncoder().encode(archive)!;
    final result = ScheduleParser.parseBytes(bytes: bytes, extension: 'xlsx');

    expect(result.sessions, hasLength(1));
    expect(result.sessions.single.courseName, '计算机视觉');
    expect(result.sessions.single.slotStart, 5);
    expect(result.sessions.single.slotEnd, 8);
  });
}
