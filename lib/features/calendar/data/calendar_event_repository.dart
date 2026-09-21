import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/local_date.dart';
import '../domain/calendar_event.dart';

class CalendarEventRepository {
  CalendarEventRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<CalendarEventItem>> getEvents() async {
    final query = _database.select(_database.calendarEvents)
      ..where((event) => event.deletedAt.isNull())
      ..orderBy([
        (event) => OrderingTerm(expression: event.eventDate),
        (event) => OrderingTerm(expression: event.createdAt),
      ]);
    final rows = await query.get();
    return rows.map(CalendarEventItem.fromRow).toList(growable: false);
  }

  Future<CalendarEventItem> createEvent({
    required String title,
    required CalendarEventType type,
    required String eventDate,
    bool repeatsYearly = true,
    String? notes,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('名称不能为空');
    }
    final normalizedDate = localDateKey(DateTime.parse(eventDate));
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: id,
            title: normalizedTitle,
            eventType: Value(type.storage),
            eventDate: normalizedDate,
            repeatsYearly: Value(repeatsYearly),
            notes: Value(_nullableText(notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getEvent(id);
  }

  Future<CalendarEventItem> updateEvent({
    required String id,
    required String title,
    required CalendarEventType type,
    required String eventDate,
    required bool repeatsYearly,
    String? notes,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('名称不能为空');
    }
    await (_database.update(
      _database.calendarEvents,
    )..where((event) => event.id.equals(id))).write(
      CalendarEventsCompanion(
        title: Value(normalizedTitle),
        eventType: Value(type.storage),
        eventDate: Value(localDateKey(DateTime.parse(eventDate))),
        repeatsYearly: Value(repeatsYearly),
        notes: Value(_nullableText(notes)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return getEvent(id);
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.calendarEvents,
    )..where((event) => event.id.equals(id))).write(
      CalendarEventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<CalendarEventItem> getEvent(String id) async {
    final row = await (_database.select(
      _database.calendarEvents,
    )..where((event) => event.id.equals(id))).getSingle();
    return CalendarEventItem.fromRow(row);
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
