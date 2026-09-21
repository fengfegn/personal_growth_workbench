import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/time/local_date.dart';
import 'package:personal_growth_workbench/features/habits/data/habit_repository.dart';
import 'package:personal_growth_workbench/features/habits/domain/habit.dart';
import 'package:personal_growth_workbench/features/habits/domain/habit_stats.dart';

void main() {
  test(
    'creates, toggles and persists one check-in per habit and date',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = HabitRepository(database);
      final habit = await repository.createHabit(
        name: '每天阅读',
        description: '至少 20 分钟',
        startDate: '2026-09-15',
      );

      expect(
        await repository.toggleCheckin(habitId: habit.id, date: '2026-09-15'),
        isTrue,
      );
      expect(
        await repository.toggleCheckin(habitId: habit.id, date: '2026-09-15'),
        isFalse,
      );
      expect(await repository.getCheckins(), isEmpty);
      expect(
        await repository.toggleCheckin(habitId: habit.id, date: '2026-09-16'),
        isTrue,
      );
      expect((await repository.getCheckins()).single.habitId, habit.id);
    },
  );

  test('archived dates preserve history but are no longer active', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = HabitRepository(database);
    final habit = await repository.createHabit(
      name: '运动',
      startDate: '2026-09-01',
    );
    await repository.toggleCheckin(habitId: habit.id, date: '2026-09-16');
    await repository.setArchived(habit.id, true);
    final archived = await repository.getHabit(habit.id);
    final today = localDateKey(DateTime.now());

    expect(archived.isActiveOn('2026-09-16'), isTrue);
    expect(archived.isActiveOn(today), isFalse);
    expect(archived.isActiveOn('2026-08-31'), isFalse);
    expect((await repository.getCheckins()), hasLength(1));
    expect(
      (await repository.getHabits()).where((item) => item.id == habit.id),
      isEmpty,
    );
    expect((await repository.getHabits(includeArchived: true)), hasLength(1));
  });

  test(
    'heatmap and streak use normalized completion rate and local active dates',
    () {
      final habit = HabitItemForTest.item(
        id: 'reading',
        name: '阅读',
        startDate: '2026-09-15',
      );
      final checkins = [
        HabitCheckinItemForTest.item(habitId: 'reading', date: '2026-09-15'),
        HabitCheckinItemForTest.item(habitId: 'reading', date: '2026-09-16'),
      ];
      final stats = calculateHabitStats(
        habit: habit,
        checkins: checkins,
        today: DateTime(2026, 9, 17, 8),
      );
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
      expect(stats.totalCompletedDays, 2);
      expect(stats.last30DayRate, closeTo(2 / 3, 0.001));

      final cells = buildHeatmap(
        today: DateTime(2026, 9, 17),
        habits: [habit],
        checkins: checkins,
      );
      final today = cells.singleWhere((cell) => cell.date == '2026-09-17');
      final beforeStart = cells.singleWhere(
        (cell) => cell.date == '2026-09-14',
      );
      expect(today.completedCount, 0);
      expect(today.activeCount, 1);
      expect(today.level, 0);
      expect(beforeStart.activeCount, 0);
      expect(beforeStart.level, -1);
    },
  );

  test('monthly heatmap uses natural month cells and marks future dates', () {
    final habit = HabitItemForTest.item(
      id: 'reading',
      name: '阅读',
      startDate: '2026-09-01',
    );
    final cells = buildMonthlyHeatmap(
      year: 2026,
      month: 9,
      today: DateTime(2026, 9, 17),
      habits: [habit],
      checkins: const [],
    );

    expect(cells, hasLength(30));
    expect(cells.first.date, '2026-09-01');
    expect(cells[16].isFuture, isFalse);
    expect(cells[17].isFuture, isTrue);
    expect(cells[17].level, -2);
    expect(cells[17].activeCount, 1);
  });
}

class HabitItemForTest {
  static HabitItem item({
    required String id,
    required String name,
    required String startDate,
  }) {
    return HabitItem(
      id: id,
      name: name,
      description: null,
      icon: '●',
      color: 'primary',
      frequency: 'daily',
      startDate: startDate,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
      archivedAt: null,
    );
  }
}

class HabitCheckinItemForTest {
  static HabitCheckinItem item({
    required String habitId,
    required String date,
  }) {
    return HabitCheckinItem(
      id: '$habitId-$date',
      habitId: habitId,
      date: date,
      completedAt: DateTime.utc(2026, 9, 17),
      createdAt: DateTime.utc(2026, 9, 17),
    );
  }
}
