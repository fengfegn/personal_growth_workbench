import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/course.dart';

class CourseSessionFormValues {
  const CourseSessionFormValues({
    required this.courseName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.slotStart,
    required this.slotEnd,
    required this.note,
    this.deleteSession = false,
  });

  final String courseName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int? slotStart;
  final int? slotEnd;
  final String note;
  final bool deleteSession;
}

class CourseSessionEditorDialog extends StatefulWidget {
  const CourseSessionEditorDialog({this.initialDate, this.session, super.key});

  final DateTime? initialDate;
  final CourseSessionItem? session;

  @override
  State<CourseSessionEditorDialog> createState() =>
      _CourseSessionEditorDialogState();
}

class _CourseSessionEditorDialogState extends State<CourseSessionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _noteController;
  late DateTime _date;
  int? _slotStart;
  int? _slotEnd;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _nameController = TextEditingController(text: session?.courseName ?? '');
    _startController = TextEditingController(
      text: session?.startTime ?? '08:30',
    );
    _endController = TextEditingController(text: session?.endTime ?? '10:05');
    _noteController = TextEditingController(text: session?.note ?? '');
    _date = session == null
        ? widget.initialDate ?? DateTime.now()
        : DateTime.parse(session.date);
    _slotStart = session?.slotStart ?? 1;
    _slotEnd = session?.slotEnd ?? 2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.session != null;
    return AlertDialog(
      title: Text(editing ? '编辑课程安排' : '新增课程安排'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('course-name-field'),
                  controller: _nameController,
                  autofocus: !editing,
                  decoration: const InputDecoration(
                    labelText: '课程名称',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入课程名称' : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('course-date-field'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('yyyy年MM月dd日').format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('course-start-time-field'),
                        controller: _startController,
                        decoration: const InputDecoration(labelText: '开始时间'),
                        validator: _validateTime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('course-end-time-field'),
                        controller: _endController,
                        decoration: const InputDecoration(labelText: '结束时间'),
                        validator: _validateTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _slotDropdown(
                        '起始节次',
                        _slotStart,
                        (value) => setState(() => _slotStart = value),
                        end: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _slotDropdown(
                        '结束节次',
                        _slotEnd,
                        (value) => setState(() => _slotEnd = value),
                        end: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('course-note-field'),
                  controller: _noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              CourseSessionFormValues(
                courseName: _nameController.text,
                date: _date,
                startTime: _startController.text,
                endTime: _endController.text,
                slotStart: _slotStart,
                slotEnd: _slotEnd,
                note: _noteController.text,
                deleteSession: true,
              ),
            ),
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('course-save'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _slotDropdown(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    required bool end,
  }) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final slot in end ? const [2, 4, 6, 8, 10] : const [1, 3, 5, 7, 9])
          DropdownMenuItem(
            value: slot,
            child: Text(slot == 10 ? '晚课' : '$slot节'),
          ),
        DropdownMenuItem<int?>(value: null, child: Text('不指定')),
      ],
      onChanged: onChanged,
    );
  }

  String? _validateTime(String? value) {
    if (value == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value.trim())) {
      return '格式如 08:30';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CourseSessionFormValues(
        courseName: _nameController.text,
        date: _date,
        startTime: _startController.text,
        endTime: _endController.text,
        slotStart: _slotStart,
        slotEnd: _slotEnd,
        note: _noteController.text,
      ),
    );
  }
}
