import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../domain/goal.dart';

class GoalFormValues {
  const GoalFormValues({
    required this.title,
    required this.type,
    required this.parentGoalId,
    required this.description,
    required this.startDate,
    required this.targetDate,
    required this.progress,
    required this.meaning,
    required this.successCriteria,
  });

  final String title;
  final GoalType type;
  final String? parentGoalId;
  final String? description;
  final String? startDate;
  final String? targetDate;
  final int progress;
  final String? meaning;
  final String? successCriteria;
}

class GoalEditorDialog extends StatefulWidget {
  const GoalEditorDialog({this.goal, this.goals = const [], super.key});

  final GoalItem? goal;
  final List<GoalItem> goals;

  @override
  State<GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<GoalEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startDateController;
  late final TextEditingController _targetDateController;
  late final TextEditingController _meaningController;
  late final TextEditingController _successCriteriaController;
  late GoalType _type;
  late String? _parentGoalId;
  late double _progress;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title);
    _descriptionController = TextEditingController(text: goal?.description);
    _startDateController = TextEditingController(text: goal?.startDate);
    _targetDateController = TextEditingController(text: goal?.targetDate);
    _meaningController = TextEditingController(text: goal?.meaning);
    _successCriteriaController = TextEditingController(
      text: goal?.successCriteria,
    );
    _type = goal?.type ?? GoalType.longTerm;
    _parentGoalId = goal?.parentGoalId;
    _progress = (goal?.progress ?? 0).toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _targetDateController.dispose();
    _meaningController.dispose();
    _successCriteriaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = widget.goals
        .where((goal) => goal.id != widget.goal?.id)
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.goal == null ? '新建目标' : '编辑目标'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '目标名称'),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? '请输入目标名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: '目标周期',
                    prefixIcon: Icon(Icons.timelapse_outlined),
                  ),
                  items: [
                    for (final type in GoalType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _parentGoalId,
                  decoration: const InputDecoration(
                    labelText: '父目标（可选）',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无父目标'),
                    ),
                    for (final goal in parentOptions)
                      DropdownMenuItem<String?>(
                        value: goal.id,
                        child: Text(
                          goal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _parentGoalId = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        controller: _startDateController,
                        label: '开始日期',
                        onPick: () => _pickDate(_startDateController),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        controller: _targetDateController,
                        label: '目标日期',
                        onPick: () => _pickDate(_targetDateController),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('完成比例 ${_progress.round()}%'),
                ),
                Slider(
                  value: _progress,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_progress.round()}%',
                  onChanged: (value) => setState(() => _progress = value),
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '目标描述'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _meaningController,
                  decoration: const InputDecoration(labelText: '为什么重要'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _successCriteriaController,
                  decoration: const InputDecoration(labelText: '成功标准'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = DateTime.tryParse(controller.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() => controller.text = localDateKey(selected));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      GoalFormValues(
        title: _titleController.text,
        type: _type,
        parentGoalId: _parentGoalId,
        description: _descriptionController.text,
        startDate: _startDateController.text,
        targetDate: _targetDateController.text,
        progress: _progress.round(),
        meaning: _meaningController.text,
        successCriteria: _successCriteriaController.text,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.onPick,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onPick,
      decoration: InputDecoration(
        labelText: label,
        hintText: '可选',
        prefixIcon: const Icon(Icons.event_outlined),
      ),
    );
  }
}
