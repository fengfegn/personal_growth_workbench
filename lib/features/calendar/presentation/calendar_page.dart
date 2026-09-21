import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../quick_notes/application/quick_note_providers.dart';
import '../../quick_notes/domain/quick_note.dart';
import '../../quick_notes/presentation/quick_note_editor_page.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_editor_dialog.dart';
import '../../workbench/application/workbench_providers.dart';
import '../application/calendar_event_providers.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_holiday.dart';
import 'calendar_event_editor_dialog.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({this.initialDate, super.key});

  final DateTime? initialDate;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(activeTaskListProvider);
    final goals = ref.watch(activeGoalListProvider);
    final notes = ref.watch(
      quickNotesForDateProvider(localDateKey(_selectedDate)),
    );
    final monthNotes = ref.watch(
      quickNotesForMonthProvider(_localMonthKey(_visibleMonth)),
    );
    final events = ref.watch(calendarEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('日历')),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取日历失败：$error')),
        data: (items) => _buildContent(
          context,
          items,
          goals.valueOrNull ?? const [],
          notes.valueOrNull ?? const [],
          monthNotes.valueOrNull ?? const [],
          events.valueOrNull ?? const [],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<TaskItem> tasks,
    List<GoalItem> goals,
    List<QuickNoteItem> notes,
    List<QuickNoteItem> monthNotes,
    List<CalendarEventItem> events,
  ) {
    final selectedTasks = _tasksForDate(tasks, _selectedDate);
    final selectedEvents = _eventsForDate(events, _selectedDate);
    final selectedHoliday = CalendarHolidayCatalog.forDate(_selectedDate);
    final holidays = [
      ...CalendarHolidayCatalog.forYear(_visibleMonth.year - 1),
      ...CalendarHolidayCatalog.forYear(_visibleMonth.year),
      ...CalendarHolidayCatalog.forYear(_visibleMonth.year + 1),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        _MonthHeader(
                          month: _visibleMonth,
                          onPrevious: () => _moveMonth(-1),
                          onNext: () => _moveMonth(1),
                          onToday: _goToToday,
                        ),
                        const SizedBox(height: 14),
                        const _WeekdayHeader(),
                        const SizedBox(height: 8),
                        _MonthGrid(
                          month: _visibleMonth,
                          selectedDate: _selectedDate,
                          today: DateTime.now(),
                          tasks: tasks,
                          notes: monthNotes,
                          events: events,
                          holidays: holidays,
                          onDateSelected: _selectDate,
                        ),
                        const SizedBox(height: 12),
                        const _CalendarLegend(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SelectedDateHeader(
                  date: _selectedDate,
                  onCreateTask: () => _createTask(context, goals),
                  onCreateNote: () => _createQuickNote(context),
                  onCreateEvent: () => _createEvent(context),
                ),
                if (selectedHoliday != null) ...[
                  const SizedBox(height: 12),
                  _CalendarHolidaySummary(holiday: selectedHoliday),
                ],
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.celebration_outlined,
                  title: '重要日子',
                  count: selectedEvents.length,
                ),
                const SizedBox(height: 8),
                if (selectedEvents.isEmpty)
                  const _EmptySection(message: '这一天还没有生日或纪念日。')
                else
                  for (final event in selectedEvents)
                    _CalendarEventSummary(
                      event: event,
                      onEdit: () => _editEvent(context, event),
                      onDelete: () => _deleteEvent(context, event),
                    ),
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.check_circle_outline,
                  title: '任务',
                  count: selectedTasks.length,
                ),
                const SizedBox(height: 8),
                if (selectedTasks.isEmpty)
                  const _EmptySection(message: '这一天还没有安排任务。')
                else
                  for (final task in selectedTasks) _TaskSummary(task: task),
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.edit_note_outlined,
                  title: '随心记',
                  count: notes.length,
                ),
                const SizedBox(height: 8),
                if (notes.isEmpty)
                  const _EmptySection(message: '这一天还没有随心记。')
                else
                  for (final note in notes) _CalendarNoteSummary(note: note),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      if (date.year != _visibleMonth.year ||
          date.month != _visibleMonth.month) {
        _visibleMonth = DateTime(date.year, date.month);
      }
    });
  }

  void _moveMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDate = DateTime(today.year, today.month, today.day);
      _visibleMonth = DateTime(today.year, today.month);
    });
  }

  Future<void> _createTask(BuildContext context, List<GoalItem> goals) async {
    final values = await showDialog<TaskFormValues>(
      context: context,
      builder: (context) => TaskEditorDialog(
        initialScheduledDate: localDateKey(_selectedDate),
        goals: goals,
      ),
    );
    if (values == null || !context.mounted) return;

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
      _showMessage('任务已保存到本地');
    } catch (error) {
      _showMessage('操作未完成：$error');
    }
  }

  Future<void> _createQuickNote(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => QuickNoteEditorPage(initialDate: _selectedDate),
      ),
    );
    if (saved == true && context.mounted) {
      invalidateQuickNoteData(ref);
      _showMessage('随心记已保存到本地');
    }
  }

  Future<void> _createEvent(BuildContext context) async {
    final values = await showDialog<CalendarEventFormValues>(
      context: context,
      builder: (context) =>
          CalendarEventEditorDialog(initialDate: _selectedDate),
    );
    if (values == null || !context.mounted) return;

    try {
      await ref
          .read(calendarEventRepositoryProvider)
          .createEvent(
            title: values.title,
            type: values.type,
            eventDate: localDateKey(values.eventDate),
            repeatsYearly: values.repeatsYearly,
            notes: values.notes,
          );
      _refreshEvents();
      _showMessage('重要日子已保存，并同步到首页倒数');
    } catch (error) {
      _showMessage('操作未完成：$error');
    }
  }

  Future<void> _editEvent(BuildContext context, CalendarEventItem event) async {
    final values = await showDialog<CalendarEventFormValues>(
      context: context,
      builder: (context) => CalendarEventEditorDialog(event: event),
    );
    if (values == null || !context.mounted) return;

    try {
      await ref
          .read(calendarEventRepositoryProvider)
          .updateEvent(
            id: event.id,
            title: values.title,
            type: values.type,
            eventDate: localDateKey(values.eventDate),
            repeatsYearly: values.repeatsYearly,
            notes: values.notes,
          );
      _refreshEvents();
      _showMessage('重要日子已更新');
    } catch (error) {
      _showMessage('操作未完成：$error');
    }
  }

  Future<void> _deleteEvent(
    BuildContext context,
    CalendarEventItem event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除重要日子？'),
        content: Text('“${event.title}”将从日历和首页倒数中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(calendarEventRepositoryProvider).softDelete(event.id);
    _refreshEvents();
    _showMessage('重要日子已删除，本地数据已更新');
  }

  void _refreshEvents() {
    invalidateCalendarEvents(ref);
    ref.invalidate(dashboardDataProvider);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${month.month}月',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${month.year}年',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onToday,
          icon: const Icon(Icons.today_outlined, size: 18),
          label: const Text('今天'),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < weekdays.length; index++)
          Expanded(
            child: Center(
              child: Text(
                weekdays[index],
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: index == 0 || index == 6
                      ? Theme.of(context).colorScheme.tertiary
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.tasks,
    required this.notes,
    required this.events,
    required this.holidays,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final List<TaskItem> tasks;
  final List<QuickNoteItem> notes;
  final List<CalendarEventItem> events;
  final List<CalendarHoliday> holidays;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final firstGridDay = firstDay.subtract(
      Duration(days: firstDay.weekday % 7),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: compact ? 70 : 92,
            crossAxisSpacing: compact ? 2 : 6,
            mainAxisSpacing: compact ? 2 : 6,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final date = firstGridDay.add(Duration(days: index));
            return _CalendarDayCell(
              date: date,
              isCurrentMonth:
                  date.year == month.year && date.month == month.month,
              isSelected: _sameDate(date, selectedDate),
              isToday: _sameDate(date, today),
              tasks: _tasksForDate(tasks, date),
              notes: _notesForDate(notes, date),
              events: _eventsForDate(events, date),
              holiday: _holidayForDate(holidays, date),
              compact: compact,
              onTap: () => onDateSelected(date),
            );
          },
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.tasks,
    required this.notes,
    required this.events,
    required this.holiday,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final List<TaskItem> tasks;
  final List<QuickNoteItem> notes;
  final List<CalendarEventItem> events;
  final CalendarHoliday? holiday;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('calendar-day-${localDateKey(date)}'),
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compact ? 4 : 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : null,
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: 0.55),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Opacity(
          opacity: isCurrentMonth ? 1 : 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? colors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isToday ? colors.onPrimary : null,
                    fontWeight: isToday || isSelected ? FontWeight.w700 : null,
                  ),
                ),
              ),
              if (holiday != null && !compact)
                Text(
                  holiday!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: holiday!.isPublicHoliday
                        ? colors.primary
                        : colors.tertiary,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  if (events.isNotEmpty)
                    _DayMarker(
                      key: ValueKey(
                        'calendar-event-count-${localDateKey(date)}',
                      ),
                      icon: Icons.celebration,
                      count: events.length,
                      color: colors.tertiary,
                    ),
                  if (tasks.isNotEmpty)
                    _DayMarker(
                      icon: Icons.check_circle,
                      count: tasks.length,
                      color: colors.primary,
                    ),
                  if (notes.isNotEmpty)
                    _DayMarker(
                      key: ValueKey(
                        'calendar-note-count-${localDateKey(date)}',
                      ),
                      icon: Icons.edit_note,
                      count: notes.length,
                      color: colors.secondary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.icon,
    required this.count,
    required this.color,
    super.key,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          if (count > 1)
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        _LegendItem(
          icon: Icons.celebration,
          label: '重要日子',
          color: colors.tertiary,
        ),
        _LegendItem(
          icon: Icons.check_circle,
          label: '任务',
          color: colors.primary,
        ),
        _LegendItem(
          icon: Icons.edit_note,
          label: '随心记',
          color: colors.secondary,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SelectedDateHeader extends StatelessWidget {
  const _SelectedDateHeader({
    required this.date,
    required this.onCreateTask,
    required this.onCreateNote,
    required this.onCreateEvent,
  });

  final DateTime date;
  final VoidCallback onCreateTask;
  final VoidCallback onCreateNote;
  final VoidCallback onCreateEvent;

  static const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${date.year}年 · ${weekdays[date.weekday - 1]}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('calendar-create-event'),
              onPressed: onCreateEvent,
              icon: const Icon(Icons.celebration_outlined),
              label: const Text('重要日子'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('calendar-create-task'),
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('任务'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('calendar-create-quick-note'),
              onPressed: onCreateNote,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('随心记'),
            ),
          ],
        );
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CalendarEventSummary extends StatelessWidget {
  const _CalendarEventSummary({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEventItem event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_eventIcon(event.type), size: 20)),
      title: Text(event.title),
      subtitle: Text(
        [
          event.type.label,
          if (event.repeatsYearly) '每年重复',
          if (event.notes?.isNotEmpty == true) event.notes!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '更多操作',
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}

class _TaskSummary extends StatelessWidget {
  const _TaskSummary({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.isCompleted ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(task.title),
      subtitle: Text(task.status.label),
    );
  }
}

class _CalendarHolidaySummary extends StatelessWidget {
  const _CalendarHolidaySummary({required this.holiday});

  final CalendarHoliday holiday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            holiday.isPublicHoliday
                ? Icons.beach_access_outlined
                : Icons.celebration_outlined,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${holiday.name} · ${holiday.typeLabel}')),
        ],
      ),
    );
  }
}

class _CalendarNoteSummary extends StatelessWidget {
  const _CalendarNoteSummary({required this.note});

  final QuickNoteItem note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        note.pinned ? Icons.push_pin : Icons.edit_note_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(note.title?.isNotEmpty == true ? note.title! : note.preview),
      subtitle: note.title?.isNotEmpty == true ? Text(note.preview) : null,
    );
  }
}

IconData _eventIcon(CalendarEventType type) {
  return switch (type) {
    CalendarEventType.birthday => Icons.cake_outlined,
    CalendarEventType.anniversary => Icons.favorite_outline,
    CalendarEventType.importantDay => Icons.star_outline,
  };
}

List<TaskItem> _tasksForDate(List<TaskItem> tasks, DateTime date) {
  final key = localDateKey(date);
  return tasks
      .where((task) => task.scheduledDate == key)
      .toList(growable: false);
}

List<QuickNoteItem> _notesForDate(List<QuickNoteItem> notes, DateTime date) {
  final key = localDateKey(date);
  return notes.where((note) => note.localDate == key).toList(growable: false);
}

List<CalendarEventItem> _eventsForDate(
  List<CalendarEventItem> events,
  DateTime date,
) {
  return events.where((event) => event.occursOn(date)).toList(growable: false);
}

CalendarHoliday? _holidayForDate(
  List<CalendarHoliday> holidays,
  DateTime date,
) {
  final key = localDateKey(date);
  for (final holiday in holidays) {
    if (holiday.localDate == key) return holiday;
  }
  return null;
}

String _localMonthKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
