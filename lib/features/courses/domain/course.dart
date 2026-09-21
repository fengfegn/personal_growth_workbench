import '../../../core/database/app_database.dart';

class CourseItem {
  const CourseItem({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.color,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseItem.fromRow(Course row) {
    return CourseItem(
      id: row.id,
      name: row.name,
      teacher: row.teacher,
      classroom: row.classroom,
      color: row.color,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  final String id;
  final String name;
  final String? teacher;
  final String? classroom;
  final String? color;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CourseSessionItem {
  const CourseSessionItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseColor,
    required this.courseNote,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.slotStart,
    required this.slotEnd,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String? courseColor;
  final String? courseNote;
  final String date;
  final String startTime;
  final String endTime;
  final int? slotStart;
  final int? slotEnd;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool occupiesSlot(int slot) {
    final start = slotStart;
    final end = slotEnd;
    return start != null && end != null && start <= slot && slot <= end;
  }

  String get timeLabel => '$startTime-$endTime';

  bool get hasNote =>
      (note?.isNotEmpty ?? false) || (courseNote?.isNotEmpty ?? false);
}

class CourseWeek {
  const CourseWeek({required this.start, required this.days});

  final DateTime start;
  final List<List<CourseSessionItem>> days;

  List<CourseSessionItem> get allSessions => [for (final day in days) ...day];
}
