import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tasks/domain/task.dart';
import '../../workbench/application/workbench_providers.dart';
import '../application/goal_providers.dart';
import '../domain/goal.dart';
import 'goal_editor_dialog.dart';
import 'milestone_editor_dialog.dart';

class GoalPage extends ConsumerWidget {
  const GoalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalListProvider);
    final tasks = ref.watch(activeTaskListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标'),
        actions: [
          IconButton(
            tooltip: '新建目标',
            onPressed: () => _createGoal(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(message: error.toString()),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyGoalState(onCreate: () => _createGoal(context, ref));
          }
          final rootGoals = items
              .where(
                (goal) =>
                    goal.parentGoalId == null ||
                    !items.any((item) => item.id == goal.parentGoalId),
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '把长期方向拆成下一步可行动的阶段。',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final goal in rootGoals)
                _GoalTree(
                  goal: goal,
                  allGoals: items,
                  tasks: tasks.valueOrNull ?? const [],
                  depth: 0,
                  onEdit: (goal) => _editGoal(context, ref, goal, items),
                  onDelete: (goal) => _deleteGoal(context, ref, goal),
                  onStatusChanged: (goal, status) =>
                      _setStatus(ref, goal, status),
                  onAddMilestone: (goal) => _addMilestone(context, ref, goal),
                  onToggleMilestone: (milestone, completed) =>
                      _toggleMilestone(ref, milestone, completed),
                  onDeleteMilestone: (milestone) =>
                      _deleteMilestone(ref, milestone),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createGoal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建目标'),
      ),
    );
  }

  Future<void> _createGoal(BuildContext context, WidgetRef ref) async {
    final goals = ref.read(activeGoalListProvider).valueOrNull ?? const [];
    final values = await showDialog<GoalFormValues>(
      context: context,
      builder: (context) => GoalEditorDialog(goals: goals),
    );
    if (values == null || !context.mounted) return;
    try {
      await ref
          .read(goalRepositoryProvider)
          .createGoal(
            title: values.title,
            type: values.type,
            parentGoalId: values.parentGoalId,
            description: values.description,
            startDate: values.startDate,
            targetDate: values.targetDate,
            progress: values.progress,
            meaning: values.meaning,
            successCriteria: values.successCriteria,
          );
      invalidateGoalData(ref);
      if (!context.mounted) return;
      _showMessage(context, '目标已保存到本地');
    } catch (error) {
      if (context.mounted) _showMessage(context, '操作未完成：$error');
    }
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    GoalItem goal,
    List<GoalItem> goals,
  ) async {
    final values = await showDialog<GoalFormValues>(
      context: context,
      builder: (context) => GoalEditorDialog(goal: goal, goals: goals),
    );
    if (values == null || !context.mounted) return;
    try {
      await ref
          .read(goalRepositoryProvider)
          .updateGoal(
            id: goal.id,
            title: values.title,
            type: values.type,
            parentGoalId: values.parentGoalId,
            description: values.description,
            startDate: values.startDate,
            targetDate: values.targetDate,
            progress: values.progress,
            meaning: values.meaning,
            successCriteria: values.successCriteria,
          );
      invalidateGoalData(ref);
      if (!context.mounted) return;
      _showMessage(context, '目标已更新');
    } catch (error) {
      if (context.mounted) _showMessage(context, '操作未完成：$error');
    }
  }

  Future<void> _setStatus(
    WidgetRef ref,
    GoalItem goal,
    GoalStatus status,
  ) async {
    await ref.read(goalRepositoryProvider).setStatus(goal.id, status);
    invalidateGoalData(ref);
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalItem goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除目标？'),
        content: Text('“${goal.title}”及其子目标会从列表中移除。'),
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
    if (confirmed != true) return;
    await ref.read(goalRepositoryProvider).softDelete(goal.id);
    invalidateGoalData(ref);
  }

  Future<void> _addMilestone(
    BuildContext context,
    WidgetRef ref,
    GoalItem goal,
  ) async {
    final values = await showDialog<MilestoneFormValues>(
      context: context,
      builder: (context) => const MilestoneEditorDialog(),
    );
    if (values == null || !context.mounted) return;
    await ref
        .read(goalRepositoryProvider)
        .createMilestone(
          goalId: goal.id,
          title: values.title,
          targetDate: values.targetDate,
        );
    invalidateGoalData(ref);
  }

  Future<void> _toggleMilestone(
    WidgetRef ref,
    GoalMilestoneItem milestone,
    bool completed,
  ) async {
    await ref
        .read(goalRepositoryProvider)
        .toggleMilestone(milestone.id, completed);
    invalidateGoalData(ref);
  }

  Future<void> _deleteMilestone(
    WidgetRef ref,
    GoalMilestoneItem milestone,
  ) async {
    await ref.read(goalRepositoryProvider).softDeleteMilestone(milestone.id);
    invalidateGoalData(ref);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GoalTree extends StatelessWidget {
  const _GoalTree({
    required this.goal,
    required this.allGoals,
    required this.tasks,
    required this.depth,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onAddMilestone,
    required this.onToggleMilestone,
    required this.onDeleteMilestone,
  });

  final GoalItem goal;
  final List<GoalItem> allGoals;
  final List<TaskItem> tasks;
  final int depth;
  final ValueChanged<GoalItem> onEdit;
  final ValueChanged<GoalItem> onDelete;
  final void Function(GoalItem, GoalStatus) onStatusChanged;
  final ValueChanged<GoalItem> onAddMilestone;
  final void Function(GoalMilestoneItem, bool) onToggleMilestone;
  final ValueChanged<GoalMilestoneItem> onDeleteMilestone;

  @override
  Widget build(BuildContext context) {
    final children = allGoals
        .where((item) => item.parentGoalId == goal.id)
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0, bottom: 12),
      child: Column(
        children: [
          _GoalCard(
            goal: goal,
            tasks: tasks,
            onEdit: () => onEdit(goal),
            onDelete: () => onDelete(goal),
            onStatusChanged: (status) => onStatusChanged(goal, status),
            onAddMilestone: () => onAddMilestone(goal),
            onToggleMilestone: onToggleMilestone,
            onDeleteMilestone: onDeleteMilestone,
          ),
          for (final child in children)
            _GoalTree(
              goal: child,
              allGoals: allGoals,
              tasks: tasks,
              depth: depth + 1,
              onEdit: onEdit,
              onDelete: onDelete,
              onStatusChanged: onStatusChanged,
              onAddMilestone: onAddMilestone,
              onToggleMilestone: onToggleMilestone,
              onDeleteMilestone: onDeleteMilestone,
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.tasks,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onAddMilestone,
    required this.onToggleMilestone,
    required this.onDeleteMilestone,
  });

  final GoalItem goal;
  final List<TaskItem> tasks;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<GoalStatus> onStatusChanged;
  final VoidCallback onAddMilestone;
  final void Function(GoalMilestoneItem, bool) onToggleMilestone;
  final ValueChanged<GoalMilestoneItem> onDeleteMilestone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(goalMilestoneListProvider(goal.id));
    final linkedTasks = tasks.where((task) => task.goalId == goal.id).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(goal.type.label),
                          Text(goal.status.label),
                          if (goal.targetDate != null)
                            Text(_countdown(goal.targetDate!)),
                          if (linkedTasks > 0) Text('$linkedTasks 个关联任务'),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<GoalStatus>(
                  tooltip: '更改目标状态',
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => [
                    for (final status in GoalStatus.values)
                      PopupMenuItem(value: status, child: Text(status.label)),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
                IconButton(
                  tooltip: '编辑目标',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除目标',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (goal.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  goal.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: goal.progress / 100),
                ),
                const SizedBox(width: 10),
                Text('${goal.progress}%'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('里程碑', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: '新增里程碑',
                  onPressed: onAddMilestone,
                  icon: const Icon(Icons.add_task),
                ),
              ],
            ),
            milestones.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('里程碑读取失败'),
              data: (items) {
                if (items.isEmpty) return const Text('还没有里程碑');
                return Column(
                  children: [
                    for (final milestone in items)
                      _MilestoneRow(
                        milestone: milestone,
                        onChanged: (value) =>
                            onToggleMilestone(milestone, value ?? false),
                        onDelete: () => onDeleteMilestone(milestone),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.onChanged,
    required this.onDelete,
  });

  final GoalMilestoneItem milestone;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: milestone.isCompleted, onChanged: onChanged),
        Expanded(
          child: Text(
            milestone.targetDate == null
                ? milestone.title
                : '${milestone.title} · ${milestone.targetDate}',
            style: milestone.isCompleted
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        ),
        IconButton(
          tooltip: '删除里程碑',
          onPressed: onDelete,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _EmptyGoalState extends StatelessWidget {
  const _EmptyGoalState({required this.onCreate});

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
              Icons.flag_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text('先写下一个值得持续投入的方向。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新建目标'),
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
    return Center(child: Text('读取目标失败：$message'));
  }
}

String _countdown(String targetDate) {
  final target = DateTime.tryParse(targetDate);
  if (target == null) return targetDate;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final targetDateOnly = DateTime(target.year, target.month, target.day);
  final days = targetDateOnly.difference(todayDate).inDays;
  if (days > 0) return '还剩 $days 天';
  if (days == 0) return '今天到期';
  return '已过期 ${-days} 天';
}
