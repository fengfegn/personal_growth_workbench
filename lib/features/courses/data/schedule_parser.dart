import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/course.dart';

class ImportedCourse {
  const ImportedCourse({
    required this.name,
    this.teacher,
    this.classroom,
    this.color,
    this.note,
  });

  final String name;
  final String? teacher;
  final String? classroom;
  final String? color;
  final String? note;
}

class ImportedSession {
  const ImportedSession({
    required this.courseName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.slotStart,
    this.slotEnd,
    this.note,
  });

  final String courseName;
  final String date;
  final String startTime;
  final String endTime;
  final int? slotStart;
  final int? slotEnd;
  final String? note;
}

class ScheduleImportResult {
  const ScheduleImportResult({
    required this.courses,
    required this.sessions,
    required this.warnings,
  });

  final List<ImportedCourse> courses;
  final List<ImportedSession> sessions;
  final List<String> warnings;

  int get courseCount => courses.length;
  int get sessionCount => sessions.length;
}

class ScheduleParser {
  static ScheduleImportResult parse({
    required String content,
    required String extension,
  }) {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (normalizedExtension == 'json') {
      return _parseJson(content);
    }
    if (normalizedExtension == 'csv') {
      return _parseDelimited(content, ',');
    }
    if (normalizedExtension == 'xlsx' || normalizedExtension == 'xls') {
      return const ScheduleImportResult(
        courses: [],
        sessions: [],
        warnings: ['当前版本无法直接读取二进制 Excel，请将课表另存为 CSV 或 Markdown 后导入。'],
      );
    }
    return _parseMarkdown(content);
  }

  static ScheduleImportResult parseBytes({
    required List<int> bytes,
    required String extension,
  }) {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (normalizedExtension == 'xlsx') return _parseXlsx(bytes);
    return parse(content: utf8.decode(bytes), extension: normalizedExtension);
  }

  static ScheduleImportResult _parseXlsx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile == null) {
        return const ScheduleImportResult(
          courses: [],
          sessions: [],
          warnings: ['Excel 工作簿中没有找到第一张工作表。'],
        );
      }
      final sharedStrings = <String>[];
      if (sharedStringsFile != null) {
        final document = XmlDocument.parse(
          utf8.decode(sharedStringsFile.content as List<int>),
        );
        for (final item in document.findAllElements('si')) {
          sharedStrings.add(
            item.findAllElements('t').map((node) => node.innerText).join(),
          );
        }
      }
      final document = XmlDocument.parse(
        utf8.decode(sheetFile.content as List<int>),
      );
      final rows = <List<String>>[];
      for (final row in document.findAllElements('row')) {
        final rowIndex =
            (int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1) - 1;
        final cells = <String>[];
        for (final cell in row.findAllElements('c')) {
          final column = _columnIndex(cell.getAttribute('r') ?? 'A');
          while (cells.length <= column) {
            cells.add('');
          }
          final values = cell.findElements('v');
          final rawValue = values.isEmpty ? '' : values.first.innerText;
          final type = cell.getAttribute('t');
          final value = type == 's'
              ? _sharedCellValue(rawValue, sharedStrings)
              : type == 'inlineStr'
              ? cell.findAllElements('t').map((node) => node.innerText).join()
              : rawValue;
          cells[column] = value;
        }
        while (rows.length <= rowIndex) {
          rows.add([]);
        }
        rows[rowIndex] = cells;
      }
      for (final merged in document.findAllElements('mergeCell')) {
        final range = _cellRange(merged.getAttribute('ref'));
        if (range == null || range.first.row >= rows.length) continue;
        final sourceRow = rows[range.first.row];
        if (range.first.column >= sourceRow.length) continue;
        final value = sourceRow[range.first.column];
        for (var row = range.first.row; row <= range.last.row; row++) {
          while (rows.length <= row) {
            rows.add([]);
          }
          while (rows[row].length <= range.last.column) {
            rows[row].add('');
          }
          for (
            var column = range.first.column;
            column <= range.last.column;
            column++
          ) {
            rows[row][column] = value;
          }
        }
      }
      final markdown = rows.map((row) => '| ${row.join(' | ')} |').join('\n');
      final result = _parseMarkdown(markdown);
      return ScheduleImportResult(
        courses: result.courses,
        sessions: result.sessions,
        warnings: ['已读取 Excel 第一张工作表。', ...result.warnings],
      );
    } catch (error) {
      return ScheduleImportResult(
        courses: const [],
        sessions: const [],
        warnings: ['Excel 文件无法读取：$error'],
      );
    }
  }

  static String _sharedCellValue(String rawValue, List<String> sharedStrings) {
    final index = int.tryParse(rawValue);
    return index != null && index >= 0 && index < sharedStrings.length
        ? sharedStrings[index]
        : '';
  }

  static int _columnIndex(String reference) {
    final letters = RegExp(r'^[A-Z]+').firstMatch(reference)?.group(0) ?? 'A';
    var result = 0;
    for (final char in letters.codeUnits) {
      result = result * 26 + char - 64;
    }
    return result - 1;
  }

  static List<_CellRef>? _cellRange(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final first = _cellReference(parts[0]);
    final last = _cellReference(parts[1]);
    if (first == null || last == null) return null;
    return [first, last];
  }

  static _CellRef? _cellReference(String value) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(value);
    if (match == null) return null;
    return _CellRef(
      int.parse(match.group(2)!) - 1,
      _columnIndex(match.group(1)!),
    );
  }

  static ScheduleImportResult _parseJson(String content) {
    final warnings = <String>[];
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return const ScheduleImportResult(
        courses: [],
        sessions: [],
        warnings: ['JSON 格式无法读取。'],
      );
    }
    if (decoded is! Map<String, dynamic>) {
      return const ScheduleImportResult(
        courses: [],
        sessions: [],
        warnings: ['JSON 顶层必须是对象。'],
      );
    }
    final courseList = decoded['courses'];
    final sessionList = decoded['sessions'];
    final courses = <ImportedCourse>[];
    final coursesById = <String, String>{};
    if (courseList is List) {
      for (final item in courseList) {
        if (item is! Map) continue;
        final name = _text(item['name']);
        if (name == null) {
          warnings.add('发现一门没有名称的课程，已跳过。');
          continue;
        }
        final course = ImportedCourse(
          name: name,
          teacher: _text(item['teacher']),
          classroom: _text(item['classroom']),
          color: _text(item['color']),
          note: _text(item['note']),
        );
        courses.add(course);
        final id = _text(item['id']);
        if (id != null) coursesById[id] = name;
      }
    }
    final sessions = <ImportedSession>[];
    if (sessionList is List) {
      for (final item in sessionList) {
        if (item is! Map) continue;
        final courseId = _text(item['courseId']) ?? _text(item['course_id']);
        final courseName =
            _text(item['courseName']) ??
            _text(item['course_name']) ??
            (courseId == null ? null : coursesById[courseId]);
        final date = _text(item['date']);
        final start = _text(item['startTime']) ?? _text(item['start_time']);
        final end = _text(item['endTime']) ?? _text(item['end_time']);
        if (courseName == null ||
            date == null ||
            start == null ||
            end == null) {
          warnings.add('发现字段不完整的课程安排，已跳过。');
          continue;
        }
        final slotStart = _int(item['slotStart'] ?? item['slot_start']);
        final slotEnd = _int(item['slotEnd'] ?? item['slot_end']);
        sessions.add(
          ImportedSession(
            courseName: courseName,
            date: date,
            startTime: start,
            endTime: end,
            slotStart: slotStart,
            slotEnd: slotEnd,
            note: _text(item['note']),
          ),
        );
        if (!courses.any((course) => course.name == courseName)) {
          courses.add(ImportedCourse(name: courseName));
          warnings.add('课程“$courseName”没有课程定义，已按名称补齐。');
        }
      }
    } else {
      warnings.add('JSON 中没有 sessions 数组。');
    }
    return _deduplicate(courses, sessions, warnings);
  }

  static ScheduleImportResult _parseMarkdown(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final tableLines = lines.where((line) => line.contains('|')).toList();
    if (tableLines.length < 2) {
      return const ScheduleImportResult(
        courses: [],
        sessions: [],
        warnings: ['没有找到课程表格，请使用“时间 | 周一 10/12 | ...”格式。'],
      );
    }
    final rows = tableLines
        .map(_splitMarkdownRow)
        .where((row) => row.length >= 2)
        .toList();
    final header = rows.first;
    final dates = <int, String>{};
    for (var column = 1; column < header.length; column++) {
      final date = _dateFromHeader(header[column]);
      if (date != null) dates[column] = date;
    }
    final warnings = <String>[];
    if (dates.isEmpty) warnings.add('表头中没有识别到日期。');
    final sessions = <ImportedSession>[];
    final previous = <int, ImportedSession>{};
    for (final row in rows.skip(1)) {
      if (_isSeparator(row.first)) continue;
      final slot = _slotFromText(row.first);
      if (slot == null) {
        warnings.add('无法识别时间段“${row.first}”。');
        continue;
      }
      for (final entry in dates.entries) {
        if (entry.key >= row.length) continue;
        var value = _cleanCell(row[entry.key]);
        if (_isEmptyCell(value)) continue;
        if (value.startsWith('↳')) {
          final old = previous[entry.key];
          if (old != null && old.courseName == value.substring(1).trim()) {
            value = old.courseName;
          } else if (old != null) {
            value = old.courseName;
          } else {
            warnings.add('“↳”没有可延续的上一节课程：${entry.value}。');
            continue;
          }
        }
        final session = ImportedSession(
          courseName: value,
          date: entry.value,
          startTime: slot.startTime,
          endTime: slot.endTime,
          slotStart: slot.start,
          slotEnd: slot.end,
        );
        sessions.add(session);
        previous[entry.key] = session;
      }
    }
    return _deduplicate(
      [
        for (final name in sessions.map((item) => item.courseName).toSet())
          ImportedCourse(name: name),
      ],
      _mergeAdjacent(sessions),
      warnings,
    );
  }

  static ScheduleImportResult _parseDelimited(
    String content,
    String delimiter,
  ) {
    final rows = content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          return line.split(delimiter).map((cell) => cell.trim()).toList();
        })
        .toList();
    if (rows.isEmpty) {
      return const ScheduleImportResult(
        courses: [],
        sessions: [],
        warnings: ['CSV 文件为空。'],
      );
    }
    final markdown = rows.map((row) => '| ${row.join(' | ')} |').join('\n');
    return _parseMarkdown(markdown);
  }

  static ScheduleImportResult _deduplicate(
    List<ImportedCourse> courses,
    List<ImportedSession> sessions,
    List<String> warnings,
  ) {
    final uniqueCourses = <String, ImportedCourse>{};
    for (final course in courses) {
      uniqueCourses[course.name.trim()] = course;
    }
    final uniqueSessions = <String, ImportedSession>{};
    for (final session in sessions) {
      final normalized = ImportedSession(
        courseName: session.courseName.trim().replaceAll(RegExp(r'\s+'), ' '),
        date: session.date.trim(),
        startTime: _normalizeTime(session.startTime),
        endTime: _normalizeTime(session.endTime),
        slotStart: session.slotStart,
        slotEnd: session.slotEnd,
        note: session.note,
      );
      final key =
          '${normalized.courseName}|${normalized.date}|${normalized.startTime}|${normalized.endTime}';
      uniqueSessions[key] = normalized;
    }
    return ScheduleImportResult(
      courses: uniqueCourses.values.toList(growable: false),
      sessions: uniqueSessions.values.toList(growable: false),
      warnings: warnings,
    );
  }

  static List<ImportedSession> _mergeAdjacent(List<ImportedSession> input) {
    final result = <ImportedSession>[];
    for (final current in input) {
      if (result.isEmpty) {
        result.add(current);
        continue;
      }
      final previous = result.last;
      if (previous.courseName == current.courseName &&
          previous.date == current.date &&
          previous.slotEnd != null &&
          current.slotStart == previous.slotEnd! + 1) {
        result[result.length - 1] = ImportedSession(
          courseName: previous.courseName,
          date: previous.date,
          startTime: previous.startTime,
          endTime: current.endTime,
          slotStart: previous.slotStart,
          slotEnd: current.slotEnd,
          note: previous.note ?? current.note,
        );
      } else {
        result.add(current);
      }
    }
    return result;
  }

  static List<String> _splitMarkdownRow(String line) {
    var value = line.trim();
    if (value.startsWith('|')) value = value.substring(1);
    if (value.endsWith('|')) value = value.substring(0, value.length - 1);
    return value.split('|').map((cell) => cell.trim()).toList();
  }

  static String? _dateFromHeader(String value) {
    final full = RegExp(
      r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})',
    ).firstMatch(value);
    if (full != null) {
      return _dateKey(
        int.parse(full.group(1)!),
        int.parse(full.group(2)!),
        int.parse(full.group(3)!),
      );
    }
    final short = RegExp(r'(\d{1,2})\s*[月/]\s*(\d{1,2})').firstMatch(value);
    if (short != null) {
      return _dateKey(
        DateTime.now().year,
        int.parse(short.group(1)!),
        int.parse(short.group(2)!),
      );
    }
    return null;
  }

  static _Slot? _slotFromText(String value) {
    final range = RegExp(r'(\d+)\s*[-~至]\s*(\d+)').firstMatch(value);
    if (value.contains('晚课') || value.contains('晚課')) {
      return const _Slot(9, 10, '18:00', '20:30');
    }
    if (range == null) return null;
    final start = int.parse(range.group(1)!);
    final end = int.parse(range.group(2)!);
    final standard = <String, List<String>>{
      '1-2': ['08:30', '10:05'],
      '3-4': ['10:25', '12:00'],
      '5-6': ['13:30', '15:05'],
      '7-8': ['15:25', '17:00'],
    };
    final times = standard['$start-$end'];
    final explicit = RegExp(
      r'(\d{1,2}:\d{2})\s*[-~至]\s*(\d{1,2}:\d{2})',
    ).firstMatch(value);
    return _Slot(
      start,
      end,
      explicit?.group(1) ?? times?.first ?? '00:00',
      explicit?.group(2) ?? times?.last ?? '00:00',
    );
  }

  static String _cleanCell(String value) =>
      value.replaceAll(RegExp(r'<br\s*/?>'), ' ').trim();

  static bool _isEmptyCell(String value) =>
      value.isEmpty || const {'-', '/', '无', '空白'}.contains(value);

  static bool _isSeparator(String value) =>
      value.replaceAll(RegExp(r'[-:\s|]'), '').isEmpty;

  static String? _text(dynamic value) =>
      value?.toString().trim().isEmpty == true
      ? null
      : value?.toString().trim();

  static int? _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static String _normalizeTime(String value) =>
      value.trim().replaceAll('：', ':');

  static String _dateKey(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

class _Slot {
  const _Slot(this.start, this.end, this.startTime, this.endTime);

  final int start;
  final int end;
  final String startTime;
  final String endTime;
}

class _CellRef {
  const _CellRef(this.row, this.column);

  final int row;
  final int column;
}

String scheduleToJson({
  required List<CourseItem> courses,
  required List<CourseSessionItem> sessions,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'courses': [
      for (final course in courses)
        {
          'id': course.id,
          'name': course.name,
          if (course.teacher != null) 'teacher': course.teacher,
          if (course.classroom != null) 'classroom': course.classroom,
          if (course.color != null) 'color': course.color,
          if (course.note != null) 'note': course.note,
        },
    ],
    'sessions': [
      for (final session in sessions)
        {
          'id': session.id,
          'courseId': session.courseId,
          'date': session.date,
          'startTime': session.startTime,
          'endTime': session.endTime,
          if (session.slotStart != null) 'slotStart': session.slotStart,
          if (session.slotEnd != null) 'slotEnd': session.slotEnd,
          if (session.note != null) 'note': session.note,
        },
    ],
  });
}

String scheduleToMarkdown({
  required DateTime weekStart,
  required List<CourseSessionItem> sessions,
}) {
  final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
  final rows = <String>[
    '# 课程安排',
    '',
    '${_dateLabel(days.first)} ~ ${_dateLabel(days.last)}',
    '',
    '| 时间 | ${days.map(_headerLabel).join(' | ')} |',
    '|---|${List.filled(7, '---').join('|')}|',
  ];
  const slots = [
    (1, 2, '1-2'),
    (3, 4, '3-4'),
    (5, 6, '5-6'),
    (7, 8, '7-8'),
    (9, 10, '晚课'),
  ];
  for (final slot in slots) {
    rows.add(
      '| ${slot.$3} | ${days.map((day) {
        final dayKey = _dateKey(day.year, day.month, day.day);
        final found = sessions.where((session) => session.date == dayKey && session.occupiesSlot(slot.$1)).toList();
        return found.isEmpty ? '' : found.first.courseName;
      }).join(' | ')} |',
    );
  }
  return rows.join('\n');
}

String _dateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _headerLabel(DateTime date) =>
    '${['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1]} ${date.month}/${date.day}';
String _dateKey(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
