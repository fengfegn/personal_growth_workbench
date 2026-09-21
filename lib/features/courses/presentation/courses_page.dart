import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/time/local_date.dart';
import '../application/course_providers.dart';
import '../data/schedule_parser.dart';
import '../domain/course.dart';
import 'course_import_guide_dialog.dart';
import 'course_import_preview_dialog.dart';
import 'course_session_editor_dialog.dart';

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(courseWeekProvider(_weekStart));
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程安排'),
        actions: [
          IconButton(
            tooltip: '新增课程',
            onPressed: () => _createSession(context),
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton<String>(
            tooltip: '课程表菜单',
            onSelected: _handleMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'import', child: Text('导入课程表')),
              PopupMenuItem(value: 'export-json', child: Text('导出 JSON')),
              PopupMenuItem(
                value: 'export-markdown',
                child: Text('导出本周 Markdown'),
              ),
            ],
          ),
        ],
      ),
      body: week.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取课程表失败：$error')),
        data: (value) => _CourseSchedule(
          week: value,
          onPrevious: () => _moveWeek(-1),
          onNext: () => _moveWeek(1),
          onToday: () => setState(() => _weekStart = _monday(DateTime.now())),
          onSessionTap: (session) => _editSession(context, session),
        ),
      ),
    );
  }

  void _moveWeek(int offset) {
    setState(() => _weekStart = _weekStart.add(Duration(days: offset * 7)));
  }

  Future<void> _handleMenu(String value) async {
    if (value == 'import') return _importSchedule();
    final repository = ref.read(courseRepositoryProvider);
    try {
      final content = value == 'export-json'
          ? await repository.exportJson()
          : await repository.exportMarkdown(_weekStart);
      final extension = value == 'export-json' ? 'json' : 'md';
      final location = await getSaveLocation(
        suggestedName: value == 'export-json'
            ? 'course_schedule.json'
            : 'course_schedule.md',
        acceptedTypeGroups: [
          XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
        ],
      );
      if (location == null) return;
      await File(location.path).writeAsString(content);
      _showMessage('课程表已导出到本地');
    } catch (error) {
      _showMessage('导出未完成：$error');
    }
  }

  Future<void> _importSchedule() async {
    try {
      final shouldChooseFile = await showDialog<bool>(
        context: context,
        builder: (context) => const CourseImportGuideDialog(),
      );
      if (shouldChooseFile != true || !mounted) return;
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: '课程表',
            extensions: ['md', 'markdown', 'csv', 'json', 'xlsx', 'xls'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final extension = file.name.contains('.')
          ? file.name.split('.').last
          : 'md';
      final result = ScheduleParser.parseBytes(
        bytes: await file.readAsBytes(),
        extension: extension,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => CourseImportPreviewDialog(result: result),
      );
      if (confirmed != true || !mounted) return;
      final stats = await ref
          .read(courseRepositoryProvider)
          .importSchedule(result);
      invalidateCourseData(ref);
      _showMessage(
        '已导入 ${stats.createdCourses} 门课程、${stats.createdSessions} 次安排',
      );
    } catch (error) {
      _showMessage('导入未完成：$error');
    }
  }

  Future<void> _createSession(BuildContext context) async {
    final values = await showDialog<CourseSessionFormValues>(
      context: context,
      builder: (context) => CourseSessionEditorDialog(initialDate: _weekStart),
    );
    if (values == null || !mounted) return;
    try {
      await ref
          .read(courseRepositoryProvider)
          .createSession(
            courseName: values.courseName,
            date: localDateKey(values.date),
            startTime: values.startTime,
            endTime: values.endTime,
            slotStart: values.slotStart,
            slotEnd: values.slotEnd,
            note: values.note,
          );
      invalidateCourseData(ref);
      _showMessage('课程安排已保存到本地');
    } catch (error) {
      _showMessage('保存未完成：$error');
    }
  }

  Future<void> _editSession(
    BuildContext context,
    CourseSessionItem session,
  ) async {
    final values = await showDialog<CourseSessionFormValues>(
      context: context,
      builder: (context) => CourseSessionEditorDialog(session: session),
    );
    if (values == null || !mounted) return;
    try {
      if (values.deleteSession) {
        await ref.read(courseRepositoryProvider).softDeleteSession(session.id);
        invalidateCourseData(ref);
        _showMessage('课程安排已删除');
        return;
      }
      await ref
          .read(courseRepositoryProvider)
          .updateSession(
            id: session.id,
            courseName: values.courseName,
            date: localDateKey(values.date),
            startTime: values.startTime,
            endTime: values.endTime,
            slotStart: values.slotStart,
            slotEnd: values.slotEnd,
            note: values.note,
          );
      invalidateCourseData(ref);
      _showMessage('课程安排已更新');
    } catch (error) {
      _showMessage('保存未完成：$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CourseSchedule extends StatelessWidget {
  const _CourseSchedule({
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSessionTap,
  });

  final CourseWeek week;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<CourseSessionItem> onSessionTap;

  @override
  Widget build(BuildContext context) {
    final end = week.start.add(const Duration(days: 6));
    final count = week.allSessions.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeekHeader(
                  weekStart: week.start,
                  weekEnd: end,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onToday: onToday,
                ),
                const SizedBox(height: 12),
                Text(
                  '$count 个课程块 · 点击课程查看备注',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _WeeklyGrid(week: week, onSessionTap: onSessionTap),
                  ),
                ),
                const SizedBox(height: 16),
                _WeekSummary(week: week),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.weekEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '上一周',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '第 ${_weekNumber(weekStart)} 周',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${DateFormat('yyyy/MM/dd').format(weekStart)} - ${DateFormat('yyyy/MM/dd').format(weekEnd)}',
              ),
            ],
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('本周')),
        IconButton(
          tooltip: '下一周',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeeklyGrid extends StatelessWidget {
  const _WeeklyGrid({required this.week, required this.onSessionTap});

  final CourseWeek week;
  final ValueChanged<CourseSessionItem> onSessionTap;
  static const timeWidth = 92.0;
  static const dayWidth = 148.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: timeWidth + dayWidth * 7,
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Row(
              children: [
                const SizedBox(width: timeWidth),
                for (var index = 0; index < 7; index++)
                  _DayHeader(
                    date: week.start.add(Duration(days: index)),
                    count: week.days[index].length,
                  ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TimeColumn(),
              for (final day in week.days)
                _DayColumn(sessions: day, onSessionTap: onSessionTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.count});

  final DateTime date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(date, DateTime.now());
    return Container(
      width: _WeeklyGrid.dayWidth,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: today ? Theme.of(context).colorScheme.primaryContainer : null,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '星期${['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1]}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.month}/${date.day} · $count 门课',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn();

  @override
  Widget build(BuildContext context) {
    const labels = [
      ('1-2', '08:30', '10:05'),
      ('3-4', '10:25', '12:00'),
      ('5-6', '13:30', '15:05'),
      ('7-8', '15:25', '17:00'),
      ('晚课', '18:00', '20:30'),
    ];
    return Column(
      children: [
        for (final label in labels)
          Container(
            width: _WeeklyGrid.timeWidth,
            height: _DayColumn.rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.$1,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(label.$2, style: Theme.of(context).textTheme.labelSmall),
                Text(label.$3, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.sessions, required this.onSessionTap});

  static const rowHeight = 84.0;
  final List<CourseSessionItem> sessions;
  final ValueChanged<CourseSessionItem> onSessionTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _WeeklyGrid.dayWidth,
      height: rowHeight * 5,
      child: Stack(
        children: [
          for (var index = 0; index < 5; index++)
            Positioned(
              top: rowHeight * index,
              left: 0,
              right: 0,
              height: rowHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: index.isEven
                      ? null
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
                  border: Border(
                    left: BorderSide(color: Theme.of(context).dividerColor),
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child:
                    sessions
                        .where((session) => _slotIndex(session) == index)
                        .isEmpty
                    ? Center(
                        child: Text(
                          '空闲',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : null,
              ),
            ),
          for (final session in sessions.where(
            (session) => _slotIndex(session) < 5,
          ))
            _CourseBlock(
              session: session,
              top: rowHeight * _slotIndex(session) + 5,
              height: rowHeight * _slotSpan(session) - 10,
              onTap: () => onSessionTap(session),
            ),
        ],
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.session,
    required this.top,
    required this.height,
    required this.onTap,
  });

  final CourseSessionItem session;
  final double top;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = _courseColor(session.courseColor, colors);
    return Positioned(
      top: top,
      left: 5,
      right: 5,
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: session.hasNote ? 16 : 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      session.courseName,
                      maxLines: height > 130 ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
                if (session.hasNote)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.notes_outlined,
                      size: 14,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.week});

  final CourseWeek week;

  @override
  Widget build(BuildContext context) {
    final busyDays = week.days.where((day) => day.isNotEmpty).length;
    final freeSlots = week.days.fold<int>(
      0,
      (sum, day) => sum + (5 - day.length).clamp(0, 5),
    );
    return Text(
      '本周 $busyDays 天有课 · $freeSlots 个时间段空闲',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

DateTime _monday(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

int _weekNumber(DateTime date) {
  final first = DateTime(date.year, 1, 1);
  return ((date.difference(first).inDays + first.weekday - 1) ~/ 7) + 1;
}

int _slotIndex(CourseSessionItem session) {
  final start = session.slotStart;
  if (start == null) return 0;
  return switch (start) {
    1 => 0,
    3 => 1,
    5 => 2,
    7 => 3,
    _ => 4,
  };
}

int _slotSpan(CourseSessionItem session) {
  final start = session.slotStart;
  final end = session.slotEnd;
  if (start == null || end == null) return 1;
  if (start >= 9) return 1;
  return ((end - start) ~/ 2) + 1;
}

Color _courseColor(String? raw, ColorScheme colors) {
  if (raw != null) {
    final value = int.tryParse(raw.replaceFirst('#', ''), radix: 16);
    if (value != null) return Color(0xFF000000 | value).withValues(alpha: 0.2);
  }
  return colors.secondaryContainer;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
