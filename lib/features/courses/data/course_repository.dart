import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/course.dart';
import 'schedule_parser.dart';

class CourseRepository {
  CourseRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<CourseItem>> getCourses() async {
    final rows =
        await (_database.select(_database.courses)
              ..where((course) => course.deletedAt.isNull())
              ..orderBy([(course) => OrderingTerm(expression: course.name)]))
            .get();
    return rows.map(CourseItem.fromRow).toList(growable: false);
  }

  Future<List<CourseSessionItem>> getSessionsByWeek(DateTime weekStart) async {
    final start = _dateKey(weekStart);
    final end = _dateKey(weekStart.add(const Duration(days: 6)));
    final query =
        _database.select(_database.courseSessions).join([
            innerJoin(
              _database.courses,
              _database.courses.id.equalsExp(_database.courseSessions.courseId),
            ),
          ])
          ..where(
            _database.courseSessions.deletedAt.isNull() &
                _database.courses.deletedAt.isNull() &
                _database.courseSessions.date.isBetweenValues(start, end),
          )
          ..orderBy([
            OrderingTerm(expression: _database.courseSessions.date),
            OrderingTerm(expression: _database.courseSessions.startTime),
          ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => _sessionFromRows(
            row.readTable(_database.courseSessions),
            row.readTable(_database.courses),
          ),
        )
        .toList(growable: false);
  }

  Future<CourseSessionItem> createSession({
    required String courseName,
    required String date,
    required String startTime,
    required String endTime,
    int? slotStart,
    int? slotEnd,
    String? note,
    String? teacher,
    String? classroom,
    String? color,
  }) async {
    final normalizedName = _required(courseName, '课程名称不能为空');
    final course = await _findOrCreateCourse(
      normalizedName,
      teacher: teacher,
      classroom: classroom,
      color: color,
    );
    final session = await _insertSession(
      courseId: course.id,
      date: date,
      startTime: startTime,
      endTime: endTime,
      slotStart: slotStart,
      slotEnd: slotEnd,
      note: note,
    );
    return _getSession(session.id);
  }

  Future<CourseSessionItem> updateSession({
    required String id,
    required String courseName,
    required String date,
    required String startTime,
    required String endTime,
    int? slotStart,
    int? slotEnd,
    String? note,
  }) async {
    final courseNameValue = _required(courseName, '课程名称不能为空');
    final session = await (_database.select(
      _database.courseSessions,
    )..where((item) => item.id.equals(id))).getSingle();
    final course = await _findOrCreateCourse(courseNameValue);
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.courseSessions,
    )..where((item) => item.id.equals(id))).write(
      CourseSessionsCompanion(
        courseId: Value(course.id),
        date: Value(_normalizeDate(date)),
        startTime: Value(_normalizeTime(startTime)),
        endTime: Value(_normalizeTime(endTime)),
        slotStart: Value(slotStart),
        slotEnd: Value(slotEnd),
        note: Value(_nullableText(note)),
        updatedAt: Value(now),
      ),
    );
    if (session.courseId != course.id) {
      await _removeUnusedCourse(session.courseId);
    }
    return _getSession(id);
  }

  Future<void> softDeleteSession(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.courseSessions,
    )..where((item) => item.id.equals(id))).write(
      CourseSessionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<ScheduleImportStats> importSchedule(
    ScheduleImportResult result,
  ) async {
    var createdCourses = 0;
    var createdSessions = 0;
    await _database.transaction(() async {
      final courseIds = <String, String>{};
      for (final imported in result.courses) {
        final existing = await _findCourseByName(imported.name);
        if (existing != null) {
          courseIds[imported.name] = existing.id;
          continue;
        }
        final course = await _insertCourse(
          imported.name,
          teacher: imported.teacher,
          classroom: imported.classroom,
          color: imported.color,
          note: imported.note,
        );
        courseIds[imported.name] = course.id;
        createdCourses++;
      }
      for (final imported in result.sessions) {
        final courseId = courseIds[imported.courseName];
        if (courseId == null) continue;
        final exists =
            await (_database.select(_database.courseSessions)..where(
                  (session) =>
                      session.courseId.equals(courseId) &
                      session.date.equals(_normalizeDate(imported.date)) &
                      session.startTime.equals(
                        _normalizeTime(imported.startTime),
                      ) &
                      session.endTime.equals(_normalizeTime(imported.endTime)) &
                      session.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (exists != null) continue;
        await _insertSession(
          courseId: courseId,
          date: imported.date,
          startTime: imported.startTime,
          endTime: imported.endTime,
          slotStart: imported.slotStart,
          slotEnd: imported.slotEnd,
          note: imported.note,
        );
        createdSessions++;
      }
    });
    return ScheduleImportStats(
      createdCourses: createdCourses,
      createdSessions: createdSessions,
    );
  }

  Future<String> exportJson() async {
    final courses = await getCourses();
    final sessions = await _getAllSessions();
    return scheduleToJson(courses: courses, sessions: sessions);
  }

  Future<String> exportMarkdown(DateTime weekStart) async {
    final sessions = await getSessionsByWeek(weekStart);
    return scheduleToMarkdown(weekStart: weekStart, sessions: sessions);
  }

  Future<List<CourseSessionItem>> _getAllSessions() async {
    final query =
        _database.select(_database.courseSessions).join([
            innerJoin(
              _database.courses,
              _database.courses.id.equalsExp(_database.courseSessions.courseId),
            ),
          ])
          ..where(
            _database.courseSessions.deletedAt.isNull() &
                _database.courses.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm(expression: _database.courseSessions.date),
            OrderingTerm(expression: _database.courseSessions.startTime),
          ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => _sessionFromRows(
            row.readTable(_database.courseSessions),
            row.readTable(_database.courses),
          ),
        )
        .toList(growable: false);
  }

  Future<CourseSessionItem> _getSession(String id) async {
    final query = _database.select(_database.courseSessions).join([
      innerJoin(
        _database.courses,
        _database.courses.id.equalsExp(_database.courseSessions.courseId),
      ),
    ])..where(_database.courseSessions.id.equals(id));
    final row = await query.getSingle();
    return _sessionFromRows(
      row.readTable(_database.courseSessions),
      row.readTable(_database.courses),
    );
  }

  CourseSessionItem _sessionFromRows(CourseSession session, Course course) {
    return CourseSessionItem(
      id: session.id,
      courseId: session.courseId,
      courseName: course.name,
      courseColor: course.color,
      courseNote: course.note,
      date: session.date,
      startTime: session.startTime,
      endTime: session.endTime,
      slotStart: session.slotStart,
      slotEnd: session.slotEnd,
      note: session.note,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
  }

  Future<Course> _findOrCreateCourse(
    String name, {
    String? teacher,
    String? classroom,
    String? color,
  }) async {
    return await _findCourseByName(name) ??
        _insertCourse(
          name,
          teacher: teacher,
          classroom: classroom,
          color: color,
        );
  }

  Future<Course?> _findCourseByName(String name) async {
    return (_database.select(_database.courses)..where(
          (course) => course.name.equals(name) & course.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<Course> _insertCourse(
    String name, {
    String? teacher,
    String? classroom,
    String? color,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.courses)
        .insert(
          CoursesCompanion.insert(
            id: id,
            name: name,
            teacher: Value(_nullableText(teacher)),
            classroom: Value(_nullableText(classroom)),
            color: Value(_nullableText(color)),
            note: Value(_nullableText(note)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_database.select(
      _database.courses,
    )..where((course) => course.id.equals(id))).getSingle();
  }

  Future<CourseSession> _insertSession({
    required String courseId,
    required String date,
    required String startTime,
    required String endTime,
    int? slotStart,
    int? slotEnd,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.courseSessions)
        .insert(
          CourseSessionsCompanion.insert(
            id: id,
            courseId: courseId,
            date: _normalizeDate(date),
            startTime: _normalizeTime(startTime),
            endTime: _normalizeTime(endTime),
            slotStart: Value(slotStart),
            slotEnd: Value(slotEnd),
            note: Value(_nullableText(note)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_database.select(
      _database.courseSessions,
    )..where((session) => session.id.equals(id))).getSingle();
  }

  Future<void> _removeUnusedCourse(String courseId) async {
    final linked =
        await (_database.select(_database.courseSessions)..where(
              (session) =>
                  session.courseId.equals(courseId) &
                  session.deletedAt.isNull(),
            ))
            .get();
    if (linked.isNotEmpty) return;
    final now = DateTime.now().toUtc();
    await (_database.update(_database.courses)
          ..where((course) => course.id.equals(courseId)))
        .write(CoursesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  String _required(String value, String message) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw ArgumentError(message);
    return normalized;
  }

  String _normalizeDate(String value) => value.trim();

  String _normalizeTime(String value) => value.trim().replaceAll('：', ':');

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class ScheduleImportStats {
  const ScheduleImportStats({
    required this.createdCourses,
    required this.createdSessions,
  });

  final int createdCourses;
  final int createdSessions;
}
