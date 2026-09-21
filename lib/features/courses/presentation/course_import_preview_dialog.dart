import 'package:flutter/material.dart';

import '../data/schedule_parser.dart';

class CourseImportPreviewDialog extends StatelessWidget {
  const CourseImportPreviewDialog({required this.result, super.key});

  final ScheduleImportResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('课程表导入预览'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '识别课程 ${result.courseCount} 门，课程安排 ${result.sessionCount} 次',
              ),
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('需要确认', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final warning in result.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $warning'),
                  ),
              ],
              const SizedBox(height: 16),
              if (result.sessions.isEmpty)
                const Text('没有可导入的有效课程安排。')
              else
                for (final session in result.sessions.take(12))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(session.courseName),
                    subtitle: Text(
                      '${session.date} · ${session.startTime}-${session.endTime}',
                    ),
                  ),
              if (result.sessions.length > 12)
                Text('另有 ${result.sessions.length - 12} 次安排将在确认后导入。'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('course-confirm-import'),
          onPressed: result.sessions.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('确认导入'),
        ),
      ],
    );
  }
}
