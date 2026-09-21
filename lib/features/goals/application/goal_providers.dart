import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../workbench/application/workbench_providers.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(appDatabaseProvider));
});

final activeGoalListProvider = FutureProvider<List<GoalItem>>((ref) {
  return ref.watch(goalRepositoryProvider).getActiveGoals();
});

final goalMilestoneListProvider =
    FutureProvider.family<List<GoalMilestoneItem>, String>((ref, goalId) {
      return ref.watch(goalRepositoryProvider).getMilestones(goalId);
    });

void invalidateGoalData(WidgetRef ref) {
  ref.invalidate(activeGoalListProvider);
  ref.invalidate(goalMilestoneListProvider);
  ref.invalidate(dashboardDataProvider);
}
