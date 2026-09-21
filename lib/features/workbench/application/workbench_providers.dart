import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/time/local_date.dart';
import '../../calendar/data/calendar_event_repository.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(appDatabaseProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
});

final userProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(userProfileRepositoryProvider).getOrCreate();
});

final activeTaskListProvider = FutureProvider<List<TaskItem>>((ref) {
  return ref.watch(taskRepositoryProvider).getActiveTasks();
});

final currentTaskListProvider = FutureProvider<List<TaskItem>>((ref) {
  return ref
      .watch(taskRepositoryProvider)
      .getActiveTasks(hideCompletedBeforeToday: true);
});

final todayTopTasksProvider = FutureProvider<List<TopTaskItem>>((ref) {
  return ref
      .watch(taskRepositoryProvider)
      .getTopTasks(localDateKey(DateTime.now()));
});

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final date = localDateKey(DateTime.now());
  final profile = await ref.watch(userProfileRepositoryProvider).getOrCreate();
  final taskRepository = ref.watch(taskRepositoryProvider);
  final goalRepository = GoalRepository(ref.watch(appDatabaseProvider));
  final calendarEventRepository = CalendarEventRepository(
    ref.watch(appDatabaseProvider),
  );
  final tasks = await taskRepository.getActiveTasks(scheduledDate: date);
  final topTasks = await taskRepository.getTopTasks(date);
  final goals = await goalRepository.getActiveGoals();
  final calendarEvents = await calendarEventRepository.getEvents();
  return DashboardData(
    nickname: profile.nickname,
    tasks: tasks,
    topTasks: topTasks,
    goals: goals,
    calendarEvents: calendarEvents,
  );
});

class DashboardData {
  const DashboardData({
    required this.nickname,
    required this.tasks,
    required this.topTasks,
    required this.goals,
    this.calendarEvents = const [],
  });

  final String nickname;
  final List<TaskItem> tasks;
  final List<TopTaskItem> topTasks;
  final List<GoalItem> goals;
  final List<CalendarEventItem> calendarEvents;

  List<CalendarEventItem> upcomingCalendarEvents(DateTime now) {
    final upcoming = calendarEvents
        .where((event) {
          return event.repeatsYearly || event.daysUntil(now) >= 0;
        })
        .toList(growable: false);
    upcoming.sort((left, right) {
      final dayComparison = left.daysUntil(now).compareTo(right.daysUntil(now));
      return dayComparison != 0
          ? dayComparison
          : left.title.compareTo(right.title);
    });
    return upcoming;
  }

  Map<int, TaskItem> get topTaskBySlot {
    final selected = {for (final item in topTasks) item.slot: item.task};
    final selectedTaskIds = selected.values.map((task) => task.id).toSet();
    final fallbackTasks = tasks.where(
      (task) => !task.isCompleted && !selectedTaskIds.contains(task.id),
    );
    final result = <int, TaskItem>{...selected};
    final fallbackIterator = fallbackTasks.iterator;

    for (var slot = 1; slot <= 3; slot++) {
      if (result.containsKey(slot) || !fallbackIterator.moveNext()) {
        continue;
      }
      result[slot] = fallbackIterator.current;
    }

    return result;
  }
}

void invalidateWorkbenchData(WidgetRef ref) {
  ref.invalidate(userProfileProvider);
  ref.invalidate(activeTaskListProvider);
  ref.invalidate(currentTaskListProvider);
  ref.invalidate(todayTopTasksProvider);
  ref.invalidate(dashboardDataProvider);
}
