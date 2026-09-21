import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/time/greeting.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../goals/domain/goal.dart';
import '../../tasks/domain/task.dart';
import '../../workbench/application/workbench_providers.dart';

class DashboardHomePage extends ConsumerWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);
    return data.when(
      loading: () => const DashboardPage(),
      error: (error, stackTrace) => const DashboardPage(),
      data: (dashboard) {
        final now = DateTime.now();
        return DashboardPage(
          now: now,
          nickname: dashboard.nickname,
          topTasks: dashboard.topTaskBySlot,
          goals: dashboard.goals,
          calendarEvents: dashboard.upcomingCalendarEvents(now),
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    this.now,
    this.nickname = '你的昵称',
    this.topTasks = const {},
    this.goals = const [],
    this.calendarEvents = const [],
    super.key,
  });

  final DateTime? now;
  final String nickname;
  final Map<int, TaskItem> topTasks;
  final List<GoalItem> goals;
  final List<CalendarEventItem> calendarEvents;

  @override
  Widget build(BuildContext context) {
    final currentTime = now ?? DateTime.now();
    final dateLabel = DateFormat('yyyy.MM.dd').format(currentTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人成长工作台'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(child: Text(dateLabel)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingFor(currentTime, nickname: nickname),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今天先完成最重要的三件事。',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  _PriorityTasksCard(topTasks: topTasks),
                  const SizedBox(height: 16),
                  _SecondaryPreviewRow(
                    goals: goals,
                    calendarEvents: calendarEvents,
                    now: currentTime,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PriorityTasksCard extends StatelessWidget {
  const _PriorityTasksCard({required this.topTasks});

  final Map<int, TaskItem> topTasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.center_focus_strong,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '今日三件事',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var index = 0; index < 3; index++)
                      SizedBox(
                        key: ValueKey('priority-slot-$index'),
                        width: slotWidth,
                        child: _PrioritySlot(
                          number: index + 1,
                          task: topTasks[index + 1],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrioritySlot extends StatelessWidget {
  const _PrioritySlot({required this.number, this.task});

  final int number;
  final TaskItem? task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 $number 件',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            task?.title ?? '还没有安排事项',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: task == null ? null : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryPreviewRow extends StatelessWidget {
  const _SecondaryPreviewRow({
    required this.goals,
    required this.calendarEvents,
    required this.now,
  });

  final List<GoalItem> goals;
  final List<CalendarEventItem> calendarEvents;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: goals.isEmpty
                  ? const _PreviewCard(
                      icon: Icons.flag_outlined,
                      title: '最近目标',
                      message: '准备好后，从一个小目标开始。',
                    )
                  : _GoalPreviewCard(goal: goals.first, now: now),
            ),
            SizedBox(
              width: width,
              child: calendarEvents.isEmpty
                  ? const _PreviewCard(
                      icon: Icons.celebration_outlined,
                      title: '重要日子',
                      message: '在日历中添加生日或纪念日。',
                    )
                  : _CalendarEventPreviewCard(
                      event: calendarEvents.first,
                      now: now,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  const _GoalPreviewCard({required this.goal, required this.now});

  final GoalItem goal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.flag_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最近目标', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: goal.progress / 100,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${goal.progress}%'),
                    ],
                  ),
                  if (goal.targetDate != null) ...[
                    const SizedBox(height: 6),
                    Text(_goalCountdown(goal.targetDate!, now)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventPreviewCard extends StatelessWidget {
  const _CalendarEventPreviewCard({required this.event, required this.now});

  final CalendarEventItem event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = event.daysUntil(now);
    final occurrence = event.nextOccurrence(now);
    final countdown = days == 0 ? '就是今天' : '还有 $days 天';
    return Card(
      key: const ValueKey('dashboard-calendar-countdown'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              child: Icon(
                _calendarEventIcon(event.type),
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('重要日子', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${occurrence.month}月${occurrence.day}日 · ${event.type.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                countdown,
                key: const ValueKey('dashboard-calendar-countdown-label'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _goalCountdown(String targetDate, DateTime now) {
  final target = DateTime.tryParse(targetDate);
  if (target == null) return targetDate;
  final today = DateTime(now.year, now.month, now.day);
  final targetDateOnly = DateTime(target.year, target.month, target.day);
  final days = targetDateOnly.difference(today).inDays;
  if (days > 0) return '还剩 $days 天';
  if (days == 0) return '今天到期';
  return '已过期 ${-days} 天';
}

IconData _calendarEventIcon(CalendarEventType type) {
  return switch (type) {
    CalendarEventType.birthday => Icons.cake_outlined,
    CalendarEventType.anniversary => Icons.favorite_outline,
    CalendarEventType.importantDay => Icons.star_outline,
  };
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
