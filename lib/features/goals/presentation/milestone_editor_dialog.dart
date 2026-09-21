import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';

class MilestoneFormValues {
  const MilestoneFormValues({required this.title, required this.targetDate});

  final String title;
  final String? targetDate;
}

class MilestoneEditorDialog extends StatefulWidget {
  const MilestoneEditorDialog({super.key});

  @override
  State<MilestoneEditorDialog> createState() => _MilestoneEditorDialogState();
}

class _MilestoneEditorDialogState extends State<MilestoneEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _dateController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增里程碑'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '里程碑名称'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? '请输入里程碑名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: '目标日期',
                  hintText: '可选',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
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
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              MilestoneFormValues(
                title: _titleController.text,
                targetDate: _dateController.text,
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('添加'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() => _dateController.text = localDateKey(selected));
    }
  }
}
