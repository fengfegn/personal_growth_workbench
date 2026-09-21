import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/calendar_event.dart';

class CalendarEventFormValues {
  const CalendarEventFormValues({
    required this.title,
    required this.type,
    required this.eventDate,
    required this.repeatsYearly,
    required this.notes,
  });

  final String title;
  final CalendarEventType type;
  final DateTime eventDate;
  final bool repeatsYearly;
  final String? notes;
}

class CalendarEventEditorDialog extends StatefulWidget {
  const CalendarEventEditorDialog({this.initialDate, this.event, super.key});

  final DateTime? initialDate;
  final CalendarEventItem? event;

  @override
  State<CalendarEventEditorDialog> createState() =>
      _CalendarEventEditorDialogState();
}

class _CalendarEventEditorDialogState extends State<CalendarEventEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _eventDate;
  late CalendarEventType _type;
  late bool _repeatsYearly;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _notesController = TextEditingController(text: event?.notes ?? '');
    _eventDate = event?.date ?? widget.initialDate ?? DateTime.now();
    _type = event?.type ?? CalendarEventType.importantDay;
    _repeatsYearly = event?.repeatsYearly ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return AlertDialog(
      title: Text(isEditing ? '编辑重要日子' : '新建重要日子'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('calendar-event-title-field'),
                  controller: _titleController,
                  autofocus: !isEditing,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '例如：妈妈生日、结婚纪念日',
                    prefixIcon: Icon(Icons.event_note_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入名称' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<CalendarEventType>(
                  key: const ValueKey('calendar-event-type-field'),
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final type in CalendarEventType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('calendar-event-date-field'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(DateFormat('yyyy年MM月dd日').format(_eventDate)),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('每年重复'),
                  subtitle: const Text('适合生日和周年纪念日'),
                  value: _repeatsYearly,
                  onChanged: (value) => setState(() => _repeatsYearly = value),
                ),
                TextFormField(
                  key: const ValueKey('calendar-event-notes-field'),
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('calendar-event-save'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) {
      setState(() => _eventDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CalendarEventFormValues(
        title: _titleController.text,
        type: _type,
        eventDate: _eventDate,
        repeatsYearly: _repeatsYearly,
        notes: _notesController.text,
      ),
    );
  }
}
