import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/local_date.dart';
import '../../goals/data/goal_repository.dart';
import '../domain/task.dart';

class TaskAlreadySelectedException implements Exception {
  const TaskAlreadySelectedException();
}

class TaskRepository {
  TaskRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<TaskItem>> getActiveTasks({
    String? scheduledDate,
    bool hideCompletedBeforeToday = false,
  }) async {
    final query = _database.select(_database.tasks)
      ..where((task) {
        final active = task.deletedAt.isNull();
        if (scheduledDate == null) {
          return active;
        }
        return active & task.scheduledDate.equals(scheduledDate);
      })
      ..orderBy([
        (task) => OrderingTerm(expression: task.status),
        (task) => OrderingTerm(expression: task.createdAt),
      ]);
    final rows = await query.get();
    final tasks = rows.map(TaskItem.fromRow);
    if (!hideCompletedBeforeToday) {
      return tasks.toList(growable: false);
    }

    final today = localDateKey(DateTime.now());
    return tasks
        .where(
          (task) =>
              !task.isCompleted ||
              task.scheduledDate == null ||
              task.scheduledDate!.compareTo(today) >= 0,
        )
        .toList(growable: false);
  }

  Future<TaskItem> createTask({
    required String title,
    String? notes,
    String? scheduledDate,
    int priority = 0,
    DateTime? dueAt,
    String? goalId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            title: normalizedTitle,
            notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
            scheduledDate: Value(scheduledDate ?? localDateKey(DateTime.now())),
            goalId: Value(goalId),
            priority: Value(TaskPriority.fromStorage(priority).storage),
            dueAt: Value(dueAt?.toUtc()),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _syncGoalProgress(goalId);
    return getTask(id);
  }

  Future<TaskItem> updateTask({
    required String id,
    required String title,
    String? notes,
    String? scheduledDate,
    required int priority,
    required DateTime? dueAt,
    String? goalId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }

    final existing = await getTask(id);
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        title: Value(normalizedTitle),
        notes: Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
        scheduledDate: Value(scheduledDate),
        goalId: Value(goalId),
        priority: Value(TaskPriority.fromStorage(priority).storage),
        dueAt: Value(dueAt?.toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    if (existing.goalId != goalId) {
      await _syncGoalProgress(existing.goalId);
    }
    await _syncGoalProgress(goalId);
    return getTask(id);
  }

  Future<TaskItem> setStatus(String id, TaskStatus status) async {
    final existing = await getTask(id);
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        status: Value(status.name),
        completedAt: Value(
          status == TaskStatus.completed ? DateTime.now().toUtc() : null,
        ),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await _syncGoalProgress(existing.goalId);
    return getTask(id);
  }

  Future<void> softDelete(String id) async {
    final existing = await getTask(id);
    await (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await _syncGoalProgress(existing.goalId);
  }

  Future<void> _syncGoalProgress(String? goalId) async {
    if (goalId == null) return;
    await GoalRepository(_database).syncProgressForGoal(goalId);
  }

  Future<TaskItem> getTask(String id) async {
    final row = await (_database.select(
      _database.tasks,
    )..where((task) => task.id.equals(id))).getSingle();
    return TaskItem.fromRow(row);
  }

  Future<List<TopTaskItem>> getTopTasks(String localDate) async {
    final query =
        _database.select(_database.dailyTopTasks).join([
            innerJoin(
              _database.tasks,
              _database.tasks.id.equalsExp(_database.dailyTopTasks.taskId),
            ),
          ])
          ..where(
            _database.dailyTopTasks.localDate.equals(localDate) &
                _database.dailyTopTasks.deletedAt.isNull() &
                _database.tasks.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm(expression: _database.dailyTopTasks.slot)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => TopTaskItem(
            slot: row.readTable(_database.dailyTopTasks).slot,
            task: TaskItem.fromRow(row.readTable(_database.tasks)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> assignTopTask({
    required String localDate,
    required int slot,
    required String taskId,
  }) async {
    if (slot < 1 || slot > 3) {
      throw ArgumentError('今日重点任务槽位必须是 1、2 或 3');
    }

    await _database.transaction(() async {
      final task =
          await (_database.select(
                _database.tasks,
              )..where((row) => row.id.equals(taskId) & row.deletedAt.isNull()))
              .getSingleOrNull();
      if (task == null) {
        throw StateError('任务不存在或已删除');
      }

      final duplicate =
          await (_database.select(_database.dailyTopTasks)..where(
                (row) =>
                    row.localDate.equals(localDate) &
                    row.taskId.equals(taskId) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (duplicate != null && duplicate.slot != slot) {
        throw const TaskAlreadySelectedException();
      }

      final currentSlot =
          await (_database.select(_database.dailyTopTasks)..where(
                (row) =>
                    row.localDate.equals(localDate) &
                    row.slot.equals(slot) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      final now = DateTime.now().toUtc();
      if (currentSlot == null) {
        await _database
            .into(_database.dailyTopTasks)
            .insert(
              DailyTopTasksCompanion.insert(
                id: _uuid.v4(),
                localDate: localDate,
                slot: slot,
                taskId: taskId,
                selectedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_database.update(
          _database.dailyTopTasks,
        )..where((row) => row.id.equals(currentSlot.id))).write(
          DailyTopTasksCompanion(
            taskId: Value(taskId),
            selectedAt: Value(now),
            updatedAt: Value(now),
            deletedAt: const Value(null),
          ),
        );
      }
    });
  }

  Future<void> unassignTopTask({
    required String localDate,
    required int slot,
  }) async {
    final assignment =
        await (_database.select(_database.dailyTopTasks)..where(
              (row) =>
                  row.localDate.equals(localDate) &
                  row.slot.equals(slot) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (assignment == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.dailyTopTasks,
    )..where((row) => row.id.equals(assignment.id))).write(
      DailyTopTasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
