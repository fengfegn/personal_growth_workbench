import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../goals/domain/goal.dart';
import '../domain/task.dart';

class TaskFormValues {
  const TaskFormValues({
    required this.title,
    required this.notes,
    required this.scheduledDate,
    required this.dueAt,
    required this.priority,
    required this.goalId,
  });

  final String title;
  final String? notes;
  final String? scheduledDate;
  final DateTime? dueAt;
  final int priority;
  final String? goalId;
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({
    this.task,
    this.initialScheduledDate,
    this.goals = const [],
    super.key,
  });

  final TaskItem? task;
  final String? initialScheduledDate;
  final List<GoalItem> goals;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _dateController;
  late final TextEditingController _dueDateController;
  late TaskPriority _priority;
  late String? _goalId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _notesController = TextEditingController(text: widget.task?.notes);
    _dateController = TextEditingController(
      text:
          widget.task?.scheduledDate ??
          widget.initialScheduledDate ??
          localDateKey(DateTime.now()),
    );
    _dueDateController = TextEditingController(
      text: _formatDueDate(widget.task?.dueAt),
    );
    _priority = TaskPriority.fromStorage(widget.task?.priority ?? 0);
    _goalId = widget.task?.goalId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? '新建任务' : '编辑任务'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '任务标题'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? '请输入任务标题' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: '备注（可选）'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: '执行日期',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              if (widget.goals.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _goalId,
                  decoration: const InputDecoration(
                    labelText: '关联目标',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('不关联目标'),
                    ),
                    for (final goal in widget.goals)
                      DropdownMenuItem<String?>(
                        value: goal.id,
                        child: Text(
                          goal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _goalId = value),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '截至日期',
                  hintText: '可选',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _dueDateController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除截至日期',
                          onPressed: () {
                            setState(_dueDateController.clear);
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: '重要紧急程度',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  for (final priority in TaskPriority.values)
                    DropdownMenuItem(
                      value: priority,
                      child: SizedBox(
                        width: 220,
                        child: Row(
                          children: [
                            _PrioritySwatch(priority: priority),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${priority.label} · ${priority.description}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                selectedItemBuilder: (context) => [
                  for (final priority in TaskPriority.values)
                    Text(priority.label, overflow: TextOverflow.ellipsis),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.pop(
              context,
              TaskFormValues(
                title: _titleController.text,
                notes: _notesController.text,
                scheduledDate: _dateController.text.trim(),
                dueAt: _parseDueDate(_dueDateController.text),
                priority: _priority.storage,
                goalId: _goalId,
              ),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _parseDueDate(_dueDateController.text) ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10, 12, 31),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _dueDateController.text = localDateKey(selected);
    });
  }
}

DateTime? _parseDueDate(String value) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
}

String _formatDueDate(DateTime? value) {
  return value == null ? '' : localDateKey(value.toLocal());
}

class _PrioritySwatch extends StatelessWidget {
  const _PrioritySwatch({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.red => Colors.red,
      TaskPriority.yellow => Colors.amber.shade700,
      TaskPriority.green => Colors.green,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
