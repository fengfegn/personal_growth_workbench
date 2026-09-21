import '../../../core/database/app_database.dart';
import '../../../core/time/local_date.dart';

enum CalendarEventType {
  birthday('birthday', '生日'),
  anniversary('anniversary', '纪念日'),
  importantDay('important_day', '重要日子');

  const CalendarEventType(this.storage, this.label);

  final String storage;
  final String label;

  static CalendarEventType fromStorage(String value) {
    return CalendarEventType.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => CalendarEventType.importantDay,
    );
  }
}

class CalendarEventItem {
  const CalendarEventItem({
    required this.id,
    required this.title,
    required this.type,
    required this.eventDate,
    required this.repeatsYearly,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEventItem.fromRow(CalendarEvent row) {
    return CalendarEventItem(
      id: row.id,
      title: row.title,
      type: CalendarEventType.fromStorage(row.eventType),
      eventDate: row.eventDate,
      repeatsYearly: row.repeatsYearly,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  final String id;
  final String title;
  final CalendarEventType type;
  final String eventDate;
  final bool repeatsYearly;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get date => DateTime.parse(eventDate);

  DateTime occurrenceInYear(int year) {
    final source = date;
    final lastDay = DateTime(year, source.month + 1, 0).day;
    return DateTime(year, source.month, source.day.clamp(1, lastDay));
  }

  DateTime nextOccurrence(DateTime from) {
    if (!repeatsYearly) {
      return date;
    }
    final today = DateTime(from.year, from.month, from.day);
    final thisYear = occurrenceInYear(today.year);
    return thisYear.isBefore(today)
        ? occurrenceInYear(today.year + 1)
        : thisYear;
  }

  int daysUntil(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    return nextOccurrence(from).difference(today).inDays;
  }

  bool occursOn(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    if (repeatsYearly) {
      return occurrenceInYear(day.year) == day;
    }
    return eventDate == localDateKey(day);
  }
}
