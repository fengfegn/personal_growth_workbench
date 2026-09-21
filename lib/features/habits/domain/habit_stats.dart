import '../../../core/time/local_date.dart';
import 'habit.dart';

class HabitHeatmapCell {
  const HabitHeatmapCell({
    required this.date,
    required this.activeCount,
    required this.completedCount,
    required this.rate,
    required this.level,
    this.isFuture = false,
  });

  final String date;
  final int activeCount;
  final int completedCount;
  final double rate;
  final int level;
  final bool isFuture;

  bool get isEmpty => activeCount == 0;
}

class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletedDays,
    required this.last30DayRate,
    required this.todayRate,
    required this.weekRate,
    required this.monthRate,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalCompletedDays;
  final double last30DayRate;
  final double todayRate;
  final double weekRate;
  final double monthRate;
}

bool isHabitActiveOn(HabitItem habit, String date) => habit.isActiveOn(date);

Map<String, HabitCheckinItem> checkinsByHabitAndDate(
  Iterable<HabitCheckinItem> checkins,
) {
  return {
    for (final checkin in checkins)
      '${checkin.habitId}|${checkin.date}': checkin,
  };
}

HabitHeatmapCell calculateHeatmapCell({
  required String date,
  required List<HabitItem> habits,
  required Map<String, HabitCheckinItem> checkins,
  String? habitId,
  DateTime? today,
}) {
  final visibleHabits = habits
      .where((habit) => habitId == null || habit.id == habitId)
      .where((habit) => habit.isActiveOn(date))
      .toList(growable: false);
  final activeCount = visibleHabits.length;
  final completedCount = visibleHabits
      .where((habit) => checkins.containsKey('${habit.id}|$date'))
      .length;
  final rate = activeCount == 0 ? 0.0 : completedCount / activeCount;
  final currentDay = today == null
      ? null
      : DateTime(today.year, today.month, today.day);
  final parsedDate = _parseDate(date);
  final isFuture = currentDay != null && parsedDate.isAfter(currentDay);
  return HabitHeatmapCell(
    date: date,
    activeCount: activeCount,
    completedCount: completedCount,
    rate: rate,
    level: isFuture
        ? -2
        : activeCount == 0
        ? -1
        : rate == 0
        ? 0
        : (rate * 5).ceil(),
    isFuture: isFuture,
  );
}

List<HabitHeatmapCell> buildMonthlyHeatmap({
  required int year,
  required int month,
  required DateTime today,
  required List<HabitItem> habits,
  required List<HabitCheckinItem> checkins,
  String? habitId,
}) {
  final byKey = checkinsByHabitAndDate(checkins);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return [
    for (var day = 1; day <= daysInMonth; day++)
      calculateHeatmapCell(
        date: localDateKey(DateTime(year, month, day)),
        habits: habits,
        checkins: byKey,
        habitId: habitId,
        today: today,
      ),
  ];
}

List<HabitHeatmapCell> buildHeatmap({
  required DateTime today,
  required List<HabitItem> habits,
  required List<HabitCheckinItem> checkins,
  String? habitId,
  int days = 365,
}) {
  final byKey = checkinsByHabitAndDate(checkins);
  return [
    for (var offset = days - 1; offset >= 0; offset--)
      calculateHeatmapCell(
        date: localDateKey(
          DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(Duration(days: offset)),
        ),
        habits: habits,
        checkins: byKey,
        habitId: habitId,
        today: today,
      ),
  ];
}

HabitStats calculateHabitStats({
  required HabitItem habit,
  required List<HabitCheckinItem> checkins,
  required DateTime today,
}) {
  final checkinDates = checkins
      .where((item) => item.habitId == habit.id)
      .map((item) => item.date)
      .toSet();
  final todayDate = DateTime(today.year, today.month, today.day);
  final lastEffectiveDate = habit.archivedAt == null
      ? todayDate
      : DateTime(
          habit.archivedAt!.toLocal().year,
          habit.archivedAt!.toLocal().month,
          habit.archivedAt!.toLocal().day,
        ).subtract(const Duration(days: 1));

  int streakFrom(DateTime cursor) {
    var streak = 0;
    while (!cursor.isBefore(_parseDate(habit.startDate))) {
      final key = localDateKey(cursor);
      if (!habit.isActiveOn(key)) break;
      if (!checkinDates.contains(key)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  final todayKey = localDateKey(todayDate);
  final currentStreak =
      habit.isActiveOn(todayKey) && checkinDates.contains(todayKey)
      ? streakFrom(todayDate)
      : streakFrom(
          lastEffectiveDate.isBefore(todayDate)
              ? lastEffectiveDate
              : todayDate.subtract(const Duration(days: 1)),
        );

  var longest = 0;
  var running = 0;
  final start = _parseDate(habit.startDate);
  for (
    var date = start;
    !date.isAfter(lastEffectiveDate);
    date = date.add(const Duration(days: 1))
  ) {
    if (checkinDates.contains(localDateKey(date)) &&
        habit.isActiveOn(localDateKey(date))) {
      running++;
      if (running > longest) longest = running;
    } else {
      running = 0;
    }
  }

  double rateFor(int days) {
    var active = 0;
    var completed = 0;
    for (var offset = days - 1; offset >= 0; offset--) {
      final date = todayDate.subtract(Duration(days: offset));
      final key = localDateKey(date);
      if (!habit.isActiveOn(key)) continue;
      active++;
      if (checkinDates.contains(key)) completed++;
    }
    return active == 0 ? 0 : completed / active;
  }

  return HabitStats(
    currentStreak: currentStreak,
    longestStreak: longest,
    totalCompletedDays: checkinDates.length,
    last30DayRate: rateFor(30),
    todayRate: rateFor(1),
    weekRate: rateFor(7),
    monthRate: rateFor(todayDate.day),
  );
}

DateTime _parseDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
