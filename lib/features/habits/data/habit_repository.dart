import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/local_date.dart';
import '../domain/habit.dart';

class HabitRepository {
  HabitRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<HabitItem>> getHabits({bool includeArchived = false}) async {
    final query = _database.select(_database.habits)
      ..orderBy([
        (habit) => OrderingTerm(expression: habit.archivedAt),
        (habit) => OrderingTerm(expression: habit.createdAt),
      ]);
    if (!includeArchived) {
      query.where((habit) => habit.archivedAt.isNull());
    }
    final rows = await query.get();
    return rows.map(HabitItem.fromRow).toList(growable: false);
  }

  Future<List<HabitCheckinItem>> getCheckins() async {
    final rows = await (_database.select(
      _database.habitCheckins,
    )..orderBy([(checkin) => OrderingTerm(expression: checkin.date)])).get();
    return rows.map(HabitCheckinItem.fromRow).toList(growable: false);
  }

  Future<HabitItem> createHabit({
    required String name,
    String? description,
    String icon = '●',
    String color = 'primary',
    String? startDate,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('习惯名称不能为空');
    if (normalizedName.length > 30) throw ArgumentError('习惯名称不能超过 30 个字符');
    final normalizedDate = startDate ?? localDateKey(DateTime.now());
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.habits)
        .insert(
          HabitsCompanion.insert(
            id: id,
            name: normalizedName,
            description: Value(_nullableText(description)),
            icon: Value(icon.trim().isEmpty ? '●' : icon.trim()),
            color: Value(color),
            startDate: normalizedDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getHabit(id);
  }

  Future<HabitItem> updateHabit({
    required String id,
    required String name,
    String? description,
    String icon = '●',
    String color = 'primary',
    required String startDate,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('习惯名称不能为空');
    if (normalizedName.length > 30) throw ArgumentError('习惯名称不能超过 30 个字符');
    await (_database.update(
      _database.habits,
    )..where((habit) => habit.id.equals(id))).write(
      HabitsCompanion(
        name: Value(normalizedName),
        description: Value(_nullableText(description)),
        icon: Value(icon.trim().isEmpty ? '●' : icon.trim()),
        color: Value(color),
        startDate: Value(startDate),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return getHabit(id);
  }

  Future<HabitItem> getHabit(String id) async {
    final row = await (_database.select(
      _database.habits,
    )..where((habit) => habit.id.equals(id))).getSingle();
    return HabitItem.fromRow(row);
  }

  Future<void> setArchived(String id, bool archived) async {
    await (_database.update(
      _database.habits,
    )..where((habit) => habit.id.equals(id))).write(
      HabitsCompanion(
        archivedAt: Value(archived ? DateTime.now().toUtc() : null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<bool> toggleCheckin({
    required String habitId,
    required String date,
  }) async {
    final existing =
        await (_database.select(_database.habitCheckins)..where(
              (checkin) =>
                  checkin.habitId.equals(habitId) & checkin.date.equals(date),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_database.delete(
        _database.habitCheckins,
      )..where((checkin) => checkin.id.equals(existing.id))).go();
      return false;
    }
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.habitCheckins)
        .insert(
          HabitCheckinsCompanion.insert(
            id: _uuid.v4(),
            habitId: habitId,
            date: date,
            completedAt: now,
            createdAt: now,
          ),
        );
    return true;
  }

  Future<void> deletePermanently(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.habitCheckins,
      )..where((checkin) => checkin.habitId.equals(id))).go();
      await (_database.delete(
        _database.habits,
      )..where((habit) => habit.id.equals(id))).go();
    });
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
