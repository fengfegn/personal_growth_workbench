import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/local_date.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<GoalItem>> getActiveGoals() async {
    final query = _database.select(_database.goals)
      ..where((goal) => goal.deletedAt.isNull())
      ..orderBy([
        (goal) => OrderingTerm(expression: goal.status),
        (goal) => OrderingTerm(expression: goal.targetDate),
        (goal) => OrderingTerm(expression: goal.createdAt),
      ]);
    final rows = await query.get();
    for (final row in rows) {
      await syncProgressForGoal(row.id);
    }
    final refreshedRows =
        await (_database.select(_database.goals)
              ..where((goal) => goal.deletedAt.isNull())
              ..orderBy([
                (goal) => OrderingTerm(expression: goal.status),
                (goal) => OrderingTerm(expression: goal.targetDate),
                (goal) => OrderingTerm(expression: goal.createdAt),
              ]))
            .get();
    return refreshedRows.map(GoalItem.fromRow).toList(growable: false);
  }

  Future<GoalItem> createGoal({
    required String title,
    required GoalType type,
    String? parentGoalId,
    String? description,
    String? startDate,
    String? targetDate,
    int progress = 0,
    String? meaning,
    String? successCriteria,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('目标名称不能为空');
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            parentGoalId: Value(parentGoalId),
            title: normalizedTitle,
            description: Value(_nullableText(description)),
            goalType: Value(type.storage),
            startDate: Value(_nullableDate(startDate)),
            targetDate: Value(_nullableDate(targetDate)),
            progress: Value(progress.clamp(0, 100)),
            meaning: Value(_nullableText(meaning)),
            successCriteria: Value(_nullableText(successCriteria)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getGoal(id);
  }

  Future<GoalItem> updateGoal({
    required String id,
    required String title,
    required GoalType type,
    String? parentGoalId,
    String? description,
    String? startDate,
    String? targetDate,
    required int progress,
    String? meaning,
    String? successCriteria,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('目标名称不能为空');
    }
    await (_database.update(
      _database.goals,
    )..where((goal) => goal.id.equals(id))).write(
      GoalsCompanion(
        parentGoalId: Value(parentGoalId),
        title: Value(normalizedTitle),
        description: Value(_nullableText(description)),
        goalType: Value(type.storage),
        startDate: Value(_nullableDate(startDate)),
        targetDate: Value(_nullableDate(targetDate)),
        progress: Value(progress.clamp(0, 100)),
        meaning: Value(_nullableText(meaning)),
        successCriteria: Value(_nullableText(successCriteria)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await syncProgressForGoal(id);
    return getGoal(id);
  }

  Future<GoalItem> setStatus(String id, GoalStatus status) async {
    await (_database.update(
      _database.goals,
    )..where((goal) => goal.id.equals(id))).write(
      GoalsCompanion(
        status: Value(status.storage),
        progress: status == GoalStatus.completed
            ? const Value(100)
            : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return getGoal(id);
  }

  Future<GoalItem> updateProgress(String id, int progress) async {
    await (_database.update(
      _database.goals,
    )..where((goal) => goal.id.equals(id))).write(
      GoalsCompanion(
        progress: Value(progress.clamp(0, 100)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return getGoal(id);
  }

  /// Recomputes progress after linked work changes.
  ///
  /// Tasks are the primary source because they represent executable work.
  /// Milestones are used when a goal has no linked tasks. Goals without either
  /// source keep their manually maintained progress.
  Future<void> syncProgressForGoal(String goalId) async {
    final goal = await getGoal(goalId);
    if (goal.status == GoalStatus.completed) {
      if (goal.progress != 100) {
        await (_database.update(
          _database.goals,
        )..where((item) => item.id.equals(goalId))).write(
          GoalsCompanion(
            progress: const Value(100),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
      return;
    }

    final linkedTasks =
        await (_database.select(_database.tasks)..where(
              (task) => task.goalId.equals(goalId) & task.deletedAt.isNull(),
            ))
            .get();

    final trackableTasks = linkedTasks
        .where((task) => task.status != 'cancelled')
        .toList(growable: false);
    int? progress;
    if (trackableTasks.isNotEmpty) {
      final completed = trackableTasks
          .where((task) => task.status == 'completed')
          .length;
      progress = (completed / trackableTasks.length * 100).round();
    } else {
      final milestones = await getMilestones(goalId);
      if (milestones.isNotEmpty) {
        final completed = milestones.where((item) => item.isCompleted).length;
        progress = (completed / milestones.length * 100).round();
      }
    }

    if (progress == null) return;
    await (_database.update(
      _database.goals,
    )..where((goal) => goal.id.equals(goalId))).write(
      GoalsCompanion(
        progress: Value(progress.clamp(0, 100)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(_database.goals)
          ..where((goal) => goal.id.equals(id)))
        .write(GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    await (_database.update(_database.goals)
          ..where((goal) => goal.parentGoalId.equals(id)))
        .write(GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<GoalItem> getGoal(String id) async {
    final row = await (_database.select(
      _database.goals,
    )..where((goal) => goal.id.equals(id))).getSingle();
    return GoalItem.fromRow(row);
  }

  Future<List<GoalMilestoneItem>> getMilestones(String goalId) async {
    final query = _database.select(_database.goalMilestones)
      ..where(
        (milestone) =>
            milestone.goalId.equals(goalId) & milestone.deletedAt.isNull(),
      )
      ..orderBy([
        (milestone) => OrderingTerm(expression: milestone.sortOrder),
        (milestone) => OrderingTerm(expression: milestone.createdAt),
      ]);
    final rows = await query.get();
    return rows.map(GoalMilestoneItem.fromRow).toList(growable: false);
  }

  Future<GoalMilestoneItem> createMilestone({
    required String goalId,
    required String title,
    String? targetDate,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('里程碑名称不能为空');
    }
    final existing = await getMilestones(goalId);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.goalMilestones)
        .insert(
          GoalMilestonesCompanion.insert(
            id: id,
            goalId: goalId,
            title: normalizedTitle,
            targetDate: Value(_nullableDate(targetDate)),
            sortOrder: existing.length,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await syncProgressForGoal(goalId);
    return getMilestone(id);
  }

  Future<GoalMilestoneItem> toggleMilestone(String id, bool completed) async {
    final milestone = await getMilestone(id);
    await (_database.update(
      _database.goalMilestones,
    )..where((milestone) => milestone.id.equals(id))).write(
      GoalMilestonesCompanion(
        completedAt: Value(completed ? DateTime.now().toUtc() : null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await syncProgressForGoal(milestone.goalId);
    return getMilestone(id);
  }

  Future<void> softDeleteMilestone(String id) async {
    final milestone = await getMilestone(id);
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.goalMilestones,
    )..where((milestone) => milestone.id.equals(id))).write(
      GoalMilestonesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await syncProgressForGoal(milestone.goalId);
  }

  Future<GoalMilestoneItem> getMilestone(String id) async {
    final row = await (_database.select(
      _database.goalMilestones,
    )..where((milestone) => milestone.id.equals(id))).getSingle();
    return GoalMilestoneItem.fromRow(row);
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _nullableDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return localDateKey(DateTime.parse(normalized));
  }
}
