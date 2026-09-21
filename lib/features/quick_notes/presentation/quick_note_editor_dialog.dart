import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../domain/quick_note.dart';

class QuickNoteEditorResult {
  const QuickNoteEditorResult({
    required this.title,
    required this.localDate,
    required this.blocks,
    required this.tagIds,
  });

  final String? title;
  final String localDate;
  final List<QuickNoteContentBlock> blocks;
  final List<String> tagIds;
}

class QuickNoteEditorDialog extends StatefulWidget {
  const QuickNoteEditorDialog({
    required this.tags,
    this.initialDate,
    this.note,
    super.key,
  });

  final List<QuickNoteTagItem> tags;
  final DateTime? initialDate;
  final QuickNoteItem? note;

  @override
  State<QuickNoteEditorDialog> createState() => _QuickNoteEditorDialogState();
}

class _DraftBlock {
  _DraftBlock(this.type, String value)
    : controller = TextEditingController(text: value);

  QuickNoteBlockType type;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _QuickNoteEditorDialogState extends State<QuickNoteEditorDialog> {
  late final TextEditingController _titleController;
  late DateTime _selectedDate;
  late List<_DraftBlock> _blocks;
  late Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    final noteDate = widget.note?.localDate;
    final initialDate = noteDate == null
        ? widget.initialDate ?? DateTime.now()
        : DateTime.tryParse(noteDate) ?? DateTime.now();
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _blocks = [
      for (final block
          in widget.note?.blocks ?? const <QuickNoteContentBlock>[])
        _DraftBlock(block.type, block.value),
    ];
    if (_blocks.isEmpty) {
      _blocks.add(_DraftBlock(QuickNoteBlockType.text, ''));
    }
    final noteTags = widget.note?.tags ?? const <String>[];
    _selectedTagIds = {
      for (final tag in widget.tags)
        if (noteTags.contains(tag.name)) tag.id,
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;
    return AlertDialog(
      title: Text(isEditing ? '编辑随心记' : '新建随心记'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题（可选）',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
              ),
              const SizedBox(height: 12),
              _DateField(
                date: _selectedDate,
                onChanged: (date) => setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 16),
              Text('标签', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _selectedTagIds.contains(tag.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedTagIds.add(tag.id);
                        } else {
                          _selectedTagIds.remove(tag.id);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('内容', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  PopupMenuButton<QuickNoteBlockType>(
                    tooltip: '添加内容格式',
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: _addBlock,
                    itemBuilder: (context) => [
                      for (final type in QuickNoteBlockType.values)
                        PopupMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(_iconForType(type)),
                              const SizedBox(width: 8),
                              Text(type.label),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _blocks.length; index++)
                _BlockEditor(
                  key: ValueKey(_blocks[index]),
                  block: _blocks[index],
                  canDelete: _blocks.length > 1,
                  onTypeChanged: (type) =>
                      setState(() => _blocks[index].type = type),
                  onDelete: () => _removeBlock(index),
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
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  void _addBlock(QuickNoteBlockType type) {
    setState(() => _blocks.add(_DraftBlock(type, '')));
  }

  void _removeBlock(int index) {
    setState(() {
      final block = _blocks.removeAt(index);
      block.dispose();
    });
  }

  void _save() {
    final blocks = _blocks
        .map(
          (block) => QuickNoteContentBlock(
            type: block.type,
            value: block.controller.text.trim(),
          ),
        )
        .where((block) => block.value.isNotEmpty)
        .toList(growable: false);
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少添加一段内容')));
      return;
    }
    Navigator.pop(
      context,
      QuickNoteEditorResult(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        localDate: localDateKey(_selectedDate),
        blocks: blocks,
        tagIds: _selectedTagIds.toList(growable: false),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '记录日期',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text('${date.year}年${date.month}月${date.day}日'),
      ),
    );
  }
}

class _BlockEditor extends StatelessWidget {
  const _BlockEditor({
    required this.block,
    required this.canDelete,
    required this.onTypeChanged,
    required this.onDelete,
    super.key,
  });

  final _DraftBlock block;
  final bool canDelete;
  final ValueChanged<QuickNoteBlockType> onTypeChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hint = switch (block.type) {
      QuickNoteBlockType.text => '写下此刻的想法',
      QuickNoteBlockType.image => '输入图片本地路径或链接',
      QuickNoteBlockType.audio => '输入录音本地路径或链接',
      QuickNoteBlockType.video => '输入视频本地路径或链接',
      QuickNoteBlockType.emoji => '输入一个或多个表情',
      QuickNoteBlockType.link => '粘贴网页链接',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<QuickNoteBlockType>(
              value: block.type,
              onChanged: (type) {
                if (type != null) onTypeChanged(type);
              },
              items: [
                for (final type in QuickNoteBlockType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Icon(_iconForType(type)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: block.controller,
              minLines: block.type == QuickNoteBlockType.text ? 2 : 1,
              maxLines: block.type == QuickNoteBlockType.text ? 5 : 2,
              decoration: InputDecoration(labelText: hint),
            ),
          ),
          IconButton(
            tooltip: '移除内容',
            onPressed: canDelete ? onDelete : null,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

IconData _iconForType(QuickNoteBlockType type) {
  return switch (type) {
    QuickNoteBlockType.text => Icons.notes_outlined,
    QuickNoteBlockType.image => Icons.image_outlined,
    QuickNoteBlockType.audio => Icons.mic_none_outlined,
    QuickNoteBlockType.video => Icons.videocam_outlined,
    QuickNoteBlockType.emoji => Icons.emoji_emotions_outlined,
    QuickNoteBlockType.link => Icons.link_outlined,
  };
}
