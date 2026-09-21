import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../application/habit_providers.dart';
import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_stats.dart';
import 'monthly_habit_heatmap.dart';

enum HabitHeatmapView { month, year }

class HabitPage extends ConsumerStatefulWidget {
  const HabitPage({super.key});

  @override
  ConsumerState<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends ConsumerState<HabitPage> {
  String _heatmapHabitId = 'all';
  HabitHeatmapView _heatmapView = HabitHeatmapView.month;
  DateTime _heatmapPeriod = DateTime.now();
  String? _selectedHeatmapDate;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(habitDashboardProvider);
    return Scaffold(
      body: SafeArea(
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            onRetry: () => ref.invalidate(habitDashboardProvider),
          ),
          data: (data) => _buildContent(context, data),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HabitDashboardData data) {
    final habits = data.activeHabits;
    final todayHabits = data.todayHabits;
    final checkins = data.checkinsByKey;
    final today = data.today;
    final completed = data.todayCompleted;
    final total = todayHabits.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _PageHeader(onCreate: () => _openEditor(context)),
          ),
        ),
        if (habits.isEmpty && data.archivedHabits.isEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height: data.archivedHabits.isEmpty ? 440 : 300,
              child: _EmptyState(onCreate: () => _openEditor(context)),
            ),
          ),
          if (data.archivedHabits.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              sliver: SliverToBoxAdapter(
                child: _ArchivedSection(
                  habits: data.archivedHabits,
                  data: data,
                  onRestore: (habit) => _restore(context, habit),
                  onDelete: (habit) => _delete(context, habit),
                ),
              ),
            ),
        ] else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _TodaySection(
                habits: todayHabits,
                checkins: checkins,
                today: today,
                completed: completed,
                total: total,
                data: data,
                onToggle: (habit) => _toggle(habit, today, checkins),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(child: _SummarySection(data: data)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _HeatmapSection(
                habits: data.habits,
                checkins: data.checkins,
                selectedHabitId: _heatmapHabitId,
                view: _heatmapView,
                period: _heatmapPeriod,
                selectedDate: _selectedHeatmapDate,
                onHabitChanged: (value) =>
                    setState(() => _heatmapHabitId = value),
                onViewChanged: (value) => setState(() {
                  _heatmapView = value;
                  _selectedHeatmapDate = null;
                }),
                onPeriodChanged: (period) => setState(() {
                  _heatmapPeriod = period;
                  _selectedHeatmapDate = null;
                }),
                onCellTap: (cell) {
                  setState(() => _selectedHeatmapDate = cell.date);
                  _openDayDetail(context, cell.date, data);
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            sliver: SliverToBoxAdapter(
              child: _HabitListSection(
                habits: habits,
                data: data,
                onEdit: (habit) => _openEditor(context, habit: habit),
                onArchive: (habit) => _archive(context, habit),
                onDelete: (habit) => _delete(context, habit),
              ),
            ),
          ),
          if (data.archivedHabits.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              sliver: SliverToBoxAdapter(
                child: _ArchivedSection(
                  habits: data.archivedHabits,
                  data: data,
                  onRestore: (habit) => _restore(context, habit),
                  onDelete: (habit) => _delete(context, habit),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _toggle(
    HabitItem habit,
    String date,
    Map<String, HabitCheckinItem> checkins,
  ) async {
    final wasCompleted = checkins.containsKey('${habit.id}|$date');
    if (wasCompleted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('取消今日打卡？'),
          content: Text('将撤销「${habit.name}」在 $date 的完成记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认取消'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(habitRepositoryProvider)
        .toggleCheckin(habitId: habit.id, date: date);
    ref.invalidate(habitDashboardProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasCompleted ? '已取消今日打卡' : '打卡完成，继续保持')),
      );
    }
  }

  Future<void> _openEditor(BuildContext context, {HabitItem? habit}) async {
    final values = await showDialog<HabitFormValues>(
      context: context,
      builder: (_) => HabitFormDialog(habit: habit),
    );
    if (values == null) return;
    final repository = ref.read(habitRepositoryProvider);
    if (habit == null) {
      await repository.createHabit(
        name: values.name,
        description: values.description,
        icon: values.icon,
        color: values.color,
        startDate: values.startDate,
      );
    } else {
      await repository.updateHabit(
        id: habit.id,
        name: values.name,
        description: values.description,
        icon: values.icon,
        color: values.color,
        startDate: values.startDate,
      );
    }
    ref.invalidate(habitDashboardProvider);
  }

  Future<void> _archive(BuildContext context, HabitItem habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档这个习惯？'),
        content: const Text('历史打卡会保留，归档后不会再出现在今日习惯中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(habitRepositoryProvider).setArchived(habit.id, true);
      ref.invalidate(habitDashboardProvider);
    }
  }

  Future<void> _restore(BuildContext context, HabitItem habit) async {
    await ref.read(habitRepositoryProvider).setArchived(habit.id, false);
    ref.invalidate(habitDashboardProvider);
  }

  Future<void> _delete(BuildContext context, HabitItem habit) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个习惯？'),
        content: const Text('删除会同时移除该习惯的全部历史打卡记录，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认永久删除？'),
        content: Text('「${habit.name}」及其历史数据将被永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (second == true) {
      await ref.read(habitRepositoryProvider).deletePermanently(habit.id);
      ref.invalidate(habitDashboardProvider);
    }
  }

  Future<void> _openDayDetail(
    BuildContext context,
    String date,
    HabitDashboardData data,
  ) async {
    final habits = data.habits
        .where((habit) => habit.isActiveOn(date))
        .toList(growable: false);
    if (habits.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => HabitDayDetailDialog(
        date: date,
        habits: habits,
        checkins: data.checkinsByKey,
        repository: ref.read(habitRepositoryProvider),
        onChanged: () => ref.invalidate(habitDashboardProvider),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '习惯养成',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('让坚持变得可见', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('新建习惯'),
        ),
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.habits,
    required this.checkins,
    required this.today,
    required this.completed,
    required this.total,
    required this.data,
    required this.onToggle,
  });

  final List<HabitItem> habits;
  final Map<String, HabitCheckinItem> checkins;
  final String today;
  final int completed;
  final int total;
  final HabitDashboardData data;
  final ValueChanged<HabitItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '今日习惯',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$completed / $total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: rate, minHeight: 8),
            ),
            const SizedBox(height: 14),
            if (total == 0)
              Text(
                '今天还没有开始生效的习惯。',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...habits.map(
                (habit) => _TodayHabitTile(
                  habit: habit,
                  completed: checkins.containsKey('${habit.id}|$today'),
                  streak: data.statsFor(habit).currentStreak,
                  onToggle: () => onToggle(habit),
                ),
              ),
            if (total > 0 && completed == total) ...[
              const SizedBox(height: 8),
              Text(
                '今日习惯全部完成，做得很好。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayHabitTile extends StatelessWidget {
  const _TodayHabitTile({
    required this.habit,
    required this.completed,
    required this.streak,
    required this.onToggle,
  });

  final HabitItem habit;
  final bool completed;
  final int streak;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _HabitIcon(habit: habit),
      title: Text(habit.name),
      subtitle: habit.description == null
          ? null
          : Text(
              habit.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '连续 $streak 天',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: completed ? '已完成，点击取消今日打卡' : '打卡',
            onPressed: onToggle,
            icon: Icon(completed ? Icons.check : Icons.add_task),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.data});

  final HabitDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.todayHabits.length;
    final completed = data.todayCompleted;
    final week = _overallRate(data, 7);
    final month = _overallRate(data, 30);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          label: '今日完成率',
          value: '${(total == 0 ? 0 : completed / total * 100).round()}%',
          icon: Icons.today_outlined,
        ),
        _MetricCard(
          label: '本周完成率',
          value: '${(week * 100).round()}%',
          icon: Icons.date_range_outlined,
        ),
        _MetricCard(
          label: '近 30 天',
          value: '${(month * 100).round()}%',
          icon: Icons.insights_outlined,
        ),
        _MetricCard(
          label: '坚持中的习惯',
          value: '${data.activeHabits.length}',
          icon: Icons.repeat_outlined,
        ),
      ],
    );
  }

  double _overallRate(HabitDashboardData data, int days) {
    final now = DateTime.now();
    var active = 0;
    var completed = 0;
    final byKey = data.checkinsByKey;
    for (var offset = days - 1; offset >= 0; offset--) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: offset));
      final key = localDateKey(date);
      for (final habit in data.activeHabits) {
        if (!habit.isActiveOn(key)) continue;
        active++;
        if (byKey.containsKey('${habit.id}|$key')) completed++;
      }
    }
    return active == 0 ? 0 : completed / active;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapSection extends StatelessWidget {
  const _HeatmapSection({
    required this.habits,
    required this.checkins,
    required this.selectedHabitId,
    required this.view,
    required this.period,
    required this.selectedDate,
    required this.onHabitChanged,
    required this.onViewChanged,
    required this.onPeriodChanged,
    required this.onCellTap,
  });

  final List<HabitItem> habits;
  final List<HabitCheckinItem> checkins;
  final String selectedHabitId;
  final HabitHeatmapView view;
  final DateTime period;
  final String? selectedDate;
  final ValueChanged<String> onHabitChanged;
  final ValueChanged<HabitHeatmapView> onViewChanged;
  final ValueChanged<DateTime> onPeriodChanged;
  final ValueChanged<HabitHeatmapCell> onCellTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final currentPeriod = DateTime(period.year, period.month);
    final currentMonth = DateTime(today.year, today.month);
    final canGoNext = view == HabitHeatmapView.month
        ? currentPeriod.isBefore(currentMonth)
        : period.year < today.year;
    final habitId = selectedHabitId == 'all' ? null : selectedHabitId;

    List<HabitHeatmapCell> cellsFor(int year, int month) => buildMonthlyHeatmap(
      year: year,
      month: month,
      today: today,
      habits: habits,
      checkins: checkins,
      habitId: habitId,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '坚持热力图',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SegmentedButton<HabitHeatmapView>(
                  segments: const [
                    ButtonSegment(
                      value: HabitHeatmapView.month,
                      label: Text('月'),
                    ),
                    ButtonSegment(
                      value: HabitHeatmapView.year,
                      label: Text('年'),
                    ),
                  ],
                  selected: {view},
                  onSelectionChanged: (selection) =>
                      onViewChanged(selection.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: view == HabitHeatmapView.month ? '上一个月' : '上一年',
                  onPressed: () => onPeriodChanged(
                    view == HabitHeatmapView.month
                        ? DateTime(period.year, period.month - 1)
                        : DateTime(period.year - 1, period.month),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  view == HabitHeatmapView.month
                      ? '${period.year} 年 ${period.month} 月'
                      : '${period.year} 年',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: view == HabitHeatmapView.month ? '下一个月' : '下一年',
                  onPressed: canGoNext
                      ? () => onPeriodChanged(
                          view == HabitHeatmapView.month
                              ? DateTime(period.year, period.month + 1)
                              : DateTime(period.year + 1, period.month),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                DropdownButton<String>(
                  value: selectedHabitId,
                  underline: const SizedBox.shrink(),
                  hint: const Text('全部习惯'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('全部习惯')),
                    ...habits.map(
                      (habit) => DropdownMenuItem(
                        value: habit.id,
                        child: Text(habit.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onHabitChanged(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '按每日完成率计算，点击日期查看当天详情',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (view == HabitHeatmapView.month)
              MonthlyHabitHeatmap(
                year: period.year,
                month: period.month,
                cells: cellsFor(period.year, period.month),
                selectedDate: selectedDate,
                onCellTap: onCellTap,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var month = 1; month <= 12; month++) ...[
                    if (month > 1)
                      Divider(
                        height: 28,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    Text(
                      '$month 月',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MonthlyHabitHeatmap(
                      year: period.year,
                      month: month,
                      cells: cellsFor(period.year, month),
                      selectedDate: selectedDate,
                      compact: true,
                      onCellTap: onCellTap,
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            _HeatmapLegend(),
          ],
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _heatmapLegendColor(context, -1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text('N/A', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 12),
        Text('少', style: Theme.of(context).textTheme.labelSmall),
        for (var level = 0; level < 6; level++)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _heatmapLegendColor(context, level),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        Text('多', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 12),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text('未来', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

Color _heatmapLegendColor(BuildContext context, int level) {
  final scheme = Theme.of(context).colorScheme;
  if (level < 0) return scheme.surfaceContainerHighest;
  return Color.lerp(
    scheme.surfaceContainerHighest,
    scheme.primary,
    [0.08, 0.25, 0.45, 0.65, 0.82, 1.0][level.clamp(0, 5)],
  )!;
}

class _HabitListSection extends StatelessWidget {
  const _HabitListSection({
    required this.habits,
    required this.data,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });
  final List<HabitItem> habits;
  final HabitDashboardData data;
  final ValueChanged<HabitItem> onEdit;
  final ValueChanged<HabitItem> onArchive;
  final ValueChanged<HabitItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的习惯',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...habits.map(
              (habit) => _HabitListTile(
                habit: habit,
                stats: data.statsFor(habit),
                onEdit: () => onEdit(habit),
                onArchive: () => onArchive(habit),
                onDelete: () => onDelete(habit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitListTile extends StatelessWidget {
  const _HabitListTile({
    required this.habit,
    required this.stats,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });
  final HabitItem habit;
  final HabitStats stats;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _HabitIcon(habit: habit),
      title: Text(habit.name),
      subtitle: Text(
        '连续 ${stats.currentStreak} 天  ·  累计完成 ${stats.totalCompletedDays} 天  ·  创建于 ${habit.startDate}',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '更多操作',
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'archive') onArchive();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'archive', child: Text('归档')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}

class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({
    required this.habits,
    required this.data,
    required this.onRestore,
    required this.onDelete,
  });
  final List<HabitItem> habits;
  final HabitDashboardData data;
  final ValueChanged<HabitItem> onRestore;
  final ValueChanged<HabitItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('已归档习惯 (${habits.length})'),
      children: [
        for (final habit in habits)
          ListTile(
            leading: _HabitIcon(habit: habit),
            title: Text(habit.name),
            subtitle: Text('归档前连续 ${data.statsFor(habit).longestStreak} 天'),
            trailing: Wrap(
              children: [
                TextButton(
                  onPressed: () => onRestore(habit),
                  child: const Text('恢复'),
                ),
                IconButton(
                  tooltip: '永久删除',
                  onPressed: () => onDelete(habit),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HabitIcon extends StatelessWidget {
  const _HabitIcon({required this.habit});
  final HabitItem habit;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: _habitColor(
        context,
        habit.color,
      ).withValues(alpha: 0.14),
      foregroundColor: _habitColor(context, habit.color),
      child: Icon(_habitIconData(habit.icon), size: 19),
    );
  }
}

IconData _habitIconData(String value) {
  return switch (value) {
    'book' => Icons.menu_book_outlined,
    'fitness' => Icons.fitness_center_outlined,
    'learning' => Icons.school_outlined,
    'morning' => Icons.wb_sunny_outlined,
    'meditation' => Icons.self_improvement_outlined,
    'water' => Icons.water_drop_outlined,
    'writing' => Icons.edit_note_outlined,
    'work' => Icons.work_outline,
    _ => Icons.repeat_outlined,
  };
}

Color _habitColor(BuildContext context, String value) {
  final scheme = Theme.of(context).colorScheme;
  return switch (value) {
    'secondary' => scheme.secondary,
    'tertiary' => scheme.tertiary,
    'error' => scheme.error,
    'primaryContainer' => scheme.primaryContainer,
    'secondaryContainer' => scheme.secondaryContainer,
    _ => scheme.primary,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              '还没有习惯',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('从一个小习惯开始，让坚持变得看得见。', textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个习惯'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('习惯数据加载失败'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}

class HabitFormValues {
  const HabitFormValues({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.startDate,
  });
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String startDate;
}

class HabitFormDialog extends StatefulWidget {
  const HabitFormDialog({this.habit, super.key});
  final HabitItem? habit;
  @override
  State<HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends State<HabitFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _dateController;
  late String _date;
  late String _color;
  late String _icon;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _name = TextEditingController(text: habit?.name);
    _description = TextEditingController(text: habit?.description);
    _date = habit?.startDate ?? localDateKey(DateTime.now());
    _dateController = TextEditingController(text: _date);
    _icon = habit?.icon ?? 'book';
    _color = habit?.color ?? 'primary';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.habit == null ? '新建习惯' : '编辑习惯',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '创建一个每天坚持的小目标',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '习惯名称',
                    hintText: '例如：每天阅读',
                    helperText: '最多 30 个字符',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入习惯名称' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '每天至少阅读 20 分钟',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildIconPicker(context)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildColorPicker(context)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: '频率'),
                        child: Text('每天'),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: '开始日期',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: _pickDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(widget.habit == null ? '创建习惯' : '保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconPicker(BuildContext context) {
    const options = [
      ('book', '阅读'),
      ('fitness', '运动'),
      ('learning', '学习'),
      ('morning', '早起'),
      ('meditation', '冥想'),
      ('water', '喝水'),
      ('writing', '写作'),
      ('work', '通用'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('图标', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Tooltip(
                message: option.$2,
                child: ChoiceChip(
                  avatar: Icon(_habitIconData(option.$1), size: 18),
                  label: Text(option.$2),
                  selected: _icon == option.$1,
                  onSelected: (_) => setState(() => _icon = option.$1),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    const colors = [
      'primary',
      'secondary',
      'tertiary',
      'error',
      'primaryContainer',
      'secondaryContainer',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('颜色', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final color in colors)
              Semantics(
                button: true,
                selected: _color == color,
                label: '颜色 $color',
                child: Tooltip(
                  message: '颜色 $color',
                  child: InkWell(
                    onTap: () => setState(() => _color = color),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _habitColor(context, color),
                        border: Border.all(
                          color: _color == color
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: _color == color ? 3 : 1,
                        ),
                      ),
                      child: _color == color
                          ? Icon(
                              Icons.check,
                              size: 19,
                              color: Theme.of(context).colorScheme.onPrimary,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final parsed = _parseLocalDate(_date);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: parsed,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = localDateKey(picked);
      _dateController.text = _date;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      HabitFormValues(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        icon: _icon,
        color: _color,
        startDate: _date,
      ),
    );
  }
}

class HabitDayDetailDialog extends StatefulWidget {
  const HabitDayDetailDialog({
    required this.date,
    required this.habits,
    required this.checkins,
    required this.repository,
    required this.onChanged,
    super.key,
  });
  final String date;
  final List<HabitItem> habits;
  final Map<String, HabitCheckinItem> checkins;
  final HabitRepository repository;
  final VoidCallback onChanged;
  @override
  State<HabitDayDetailDialog> createState() => _HabitDayDetailDialogState();
}

class _HabitDayDetailDialogState extends State<HabitDayDetailDialog> {
  late final Set<String> _completed;
  @override
  void initState() {
    super.initState();
    _completed = {
      ...widget.checkins.keys
          .where((key) => key.endsWith('|${widget.date}'))
          .map((key) => key.split('|').first),
    };
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed.length;
    return AlertDialog(
      title: Text(_formatDate(widget.date)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final habit in widget.habits)
              CheckboxListTile(
                value: _completed.contains(habit.id),
                onChanged: (_) => _toggle(habit),
                secondary: _HabitIcon(habit: habit),
                title: Text(habit.name),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('完成 $completed / ${widget.habits.length}'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Future<void> _toggle(HabitItem habit) async {
    final value = await widget.repository.toggleCheckin(
      habitId: habit.id,
      date: widget.date,
    );
    setState(() {
      if (value) {
        _completed.add(habit.id);
      } else {
        _completed.remove(habit.id);
      }
    });
    widget.onChanged();
  }
}

String _formatDate(String value) {
  final date = _parseLocalDate(value);
  return '${date.year} 年 ${date.month} 月 ${date.day} 日';
}

DateTime _parseLocalDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
