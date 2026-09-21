import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/time/local_date.dart';
import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_stats.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(appDatabaseProvider));
});

final habitDashboardProvider = FutureProvider<HabitDashboardData>((ref) async {
  final repository = ref.watch(habitRepositoryProvider);
  final habits = await repository.getHabits(includeArchived: true);
  final checkins = await repository.getCheckins();
  return HabitDashboardData(habits: habits, checkins: checkins);
});

class HabitDashboardData {
  const HabitDashboardData({required this.habits, required this.checkins});

  final List<HabitItem> habits;
  final List<HabitCheckinItem> checkins;

  List<HabitItem> get activeHabits =>
      habits.where((habit) => !habit.isArchived).toList(growable: false);

  List<HabitItem> get archivedHabits =>
      habits.where((habit) => habit.isArchived).toList(growable: false);

  String get today => localDateKey(DateTime.now());

  List<HabitItem> get todayHabits => activeHabits
      .where((habit) => habit.isActiveOn(today))
      .toList(growable: false);

  Map<String, HabitCheckinItem> get checkinsByKey =>
      checkinsByHabitAndDate(checkins);

  int get todayCompleted => todayHabits
      .where((habit) => checkinsByKey.containsKey('${habit.id}|$today'))
      .length;

  double get todayRate =>
      todayHabits.isEmpty ? 0 : todayCompleted / todayHabits.length;

  HabitStats statsFor(HabitItem habit) => calculateHabitStats(
    habit: habit,
    checkins: checkins,
    today: DateTime.now(),
  );
}

void invalidateHabitData(WidgetRef ref) {
  ref.invalidate(habitDashboardProvider);
}
