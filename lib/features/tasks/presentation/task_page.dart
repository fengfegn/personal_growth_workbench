import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'task_editor_dialog.dart';
import '../../workbench/application/workbench_providers.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(currentTaskListProvider);
    final topTasks = ref.watch(todayTopTasksProvider);
    final goals = ref.watch(activeGoalListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('今日任务')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _createTask(context, ref, goals.valueOrNull ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(message: error.toString()),
        data: (items) {
          final topByTaskId = topTasks.maybeWhen(
            data: (top) => {for (final item in top) item.task.id: item.slot},
            orElse: () => <String, int>{},
          );
          if (items.isEmpty) {
            return _EmptyTaskState(
              onCreate: () =>
                  _createTask(context, ref, goals.valueOrNull ?? const []),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = items[index];
              return _TaskTile(
                task: task,
                topSlot: topByTaskId[task.id],
                onEdit: () => _editTask(
                  context,
                  ref,
                  task,
                  goals.valueOrNull ?? const [],
                ),
                onDelete: () => _deleteTask(context, ref, task),
                onStatusChanged: (status) => _setStatus(ref, task, status),
                onTopChanged: () => _toggleTopTask(
                  context,
                  ref,
                  task,
                  topByTaskId[task.id],
                  topByTaskId.values.toSet(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createTask(
    BuildContext context,
    WidgetRef ref,
    List<GoalItem> goals,
  ) async {
    final values = await showDialog<TaskFormValues>(
      context: context,
      builder: (context) => TaskEditorDialog(goals: goals),
    );
    if (values == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(taskRepositoryProvider)
          .createTask(
            title: values.title,
            notes: values.notes,
            scheduledDate: values.scheduledDate,
            dueAt: values.dueAt,
            priority: values.priority,
            goalId: values.goalId,
          );
      invalidateWorkbenchData(ref);
      invalidateGoalData(ref);
      if (context.mounted) {
        _showSavedMessage(context, '任务已保存到本地');
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
    List<GoalItem> goals,
  ) async {
    final values = await showDialog<TaskFormValues>(
      context: context,
      builder: (context) => TaskEditorDialog(task: task, goals: goals),
    );
    if (values == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateTask(
            id: task.id,
            title: values.title,
            notes: values.notes,
            scheduledDate: values.scheduledDate,
            dueAt: values.dueAt,
            priority: values.priority,
            goalId: values.goalId,
          );
      invalidateWorkbenchData(ref);
      invalidateGoalData(ref);
      if (context.mounted) {
        _showSavedMessage(context, '任务已更新并保存到本地');
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _setStatus(
    WidgetRef ref,
    TaskItem task,
    TaskStatus status,
  ) async {
    await ref.read(taskRepositoryProvider).setStatus(task.id, status);
    invalidateWorkbenchData(ref);
    invalidateGoalData(ref);
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务？'),
        content: Text('“${task.title}”会从当前任务列表中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(taskRepositoryProvider).softDelete(task.id);
    invalidateWorkbenchData(ref);
    invalidateGoalData(ref);
    if (context.mounted) {
      _showSavedMessage(context, '任务已删除，本地数据已经保存');
    }
  }

  Future<void> _toggleTopTask(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
    int? topSlot,
    Set<int> usedSlots,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    try {
      if (topSlot != null) {
        await repository.unassignTopTask(
          localDate: localDateKey(DateTime.now()),
          slot: topSlot,
        );
        if (context.mounted) {
          _showSavedMessage(context, '已从今日重点移除');
        }
      } else {
        final slot = _firstAvailableSlot(usedSlots);
        if (slot == null) {
          if (context.mounted) {
            _showSavedMessage(context, '今天最多安排三件重点任务');
          }
          return;
        }
        await repository.assignTopTask(
          localDate: localDateKey(DateTime.now()),
          slot: slot,
          taskId: task.id,
        );
        if (context.mounted) {
          _showSavedMessage(context, '已加入今日第 $slot 件重点任务');
        }
      }
      invalidateWorkbenchData(ref);
    } on TaskAlreadySelectedException {
      if (context.mounted) {
        _showSavedMessage(context, '这项任务已经在今日重点中');
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  int? _firstAvailableSlot(Set<int> usedSlots) {
    for (var slot = 1; slot <= 3; slot++) {
      if (!usedSlots.contains(slot)) {
        return slot;
      }
    }
    return null;
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.topSlot,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onTopChanged,
  });

  final TaskItem task;
  final int? topSlot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback onTopChanged;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Checkbox(
              value: isCompleted,
              onChanged: (value) => onStatusChanged(
                value == true ? TaskStatus.completed : TaskStatus.todo,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.notes?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.notes!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(task.status.label),
                      if (task.scheduledDate != null) Text(task.scheduledDate!),
                      if (task.dueAt != null)
                        Text('截至 ${localDateKey(task.dueAt!.toLocal())}'),
                      Tooltip(
                        message:
                            '${task.priorityLevel.label} · ${task.priorityLevel.description}',
                        child: Icon(
                          Icons.flag_rounded,
                          size: 17,
                          color: switch (task.priorityLevel) {
                            TaskPriority.red => Colors.red,
                            TaskPriority.yellow => Colors.amber.shade700,
                            TaskPriority.green => Colors.green,
                          },
                        ),
                      ),
                      if (topSlot != null)
                        Text(
                          '今日重点 $topSlot',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: topSlot == null ? '设为今日重点' : '取消今日重点',
              onPressed: onTopChanged,
              icon: Icon(
                topSlot == null ? Icons.star_border : Icons.star,
                color: topSlot == null
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            PopupMenuButton<TaskStatus>(
              tooltip: '更改任务状态',
              onSelected: onStatusChanged,
              itemBuilder: (context) => [
                for (final status in TaskStatus.values)
                  PopupMenuItem(value: status, child: Text(status.label)),
              ],
              icon: const Icon(Icons.more_vert),
            ),
            IconButton(
              tooltip: '编辑任务',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: '删除任务',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text('还没有任务，先安排一件轻量的事情吧。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('读取任务失败：$message'));
  }
}

void _showSavedMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _showError(BuildContext context, Object error) {
  _showSavedMessage(context, '操作未完成：$error');
}
