import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../core/time/local_date.dart';
import '../application/quick_note_providers.dart';
import '../domain/quick_note.dart';

class QuickNoteEditorPage extends ConsumerStatefulWidget {
  const QuickNoteEditorPage({this.initialDate, this.note, super.key});

  final DateTime? initialDate;
  final QuickNoteItem? note;

  @override
  ConsumerState<QuickNoteEditorPage> createState() =>
      _QuickNoteEditorPageState();
}

class _DraftBlock {
  _DraftBlock(this.type, String value)
    : controller = TextEditingController(text: value);

  final QuickNoteBlockType type;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _QuickNoteEditorPageState extends ConsumerState<QuickNoteEditorPage> {
  late final TextEditingController _titleController;
  late DateTime _selectedDate;
  late List<_DraftBlock> _blocks;
  Set<String> _selectedTagIds = {};
  bool _didRestoreTags = false;
  bool _saving = false;

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
    final tags = ref.watch(quickNoteTagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新建文章' : '编辑文章'),
        actions: [
          IconButton(
            key: const ValueKey('quick-note-save'),
            tooltip: '保存文章',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _ArticleToolbar(onAdd: _addBlock),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('quick-note-title-field'),
                      controller: _titleController,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: '标题',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                          ),
                          label: Text(_dateLabel(_selectedDate)),
                          onPressed: _selectDate,
                        ),
                        ...tags.when(
                          loading: () => const <Widget>[
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                          error: (error, stackTrace) => <Widget>[
                            Text('标签读取失败：$error'),
                          ],
                          data: (items) {
                            _restoreTags(items);
                            return [
                              for (final tag in items)
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
                            ];
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var index = 0; index < _blocks.length; index++)
                      _ArticleBlockEditor(
                        key: ValueKey(_blocks[index]),
                        block: _blocks[index],
                        index: index,
                        isFirst: index == 0,
                        isLast: index == _blocks.length - 1,
                        onMoveUp: () => _moveBlock(index, -1),
                        onMoveDown: () => _moveBlock(index, 1),
                        onDelete: () => _removeBlock(index),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreTags(List<QuickNoteTagItem> tags) {
    if (_didRestoreTags) return;
    final noteTags = widget.note?.tags ?? const <String>[];
    _selectedTagIds = {
      for (final tag in tags)
        if (noteTags.contains(tag.name)) tag.id,
    };
    _didRestoreTags = true;
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _addBlock(QuickNoteBlockType type) async {
    if (_isFileBlock(type)) {
      await _pickMedia(type);
      return;
    }
    setState(() => _blocks.add(_DraftBlock(type, '')));
  }

  Future<void> _pickMedia(QuickNoteBlockType type) async {
    final group = switch (type) {
      QuickNoteBlockType.image => const XTypeGroup(
        label: '图片',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
      ),
      QuickNoteBlockType.audio => const XTypeGroup(
        label: '音频',
        extensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      ),
      QuickNoteBlockType.video => const XTypeGroup(
        label: '视频',
        extensions: ['mp4', 'mov', 'mkv', 'avi', 'webm'],
      ),
      _ => throw ArgumentError('不支持的媒体类型：$type'),
    };
    try {
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null || !mounted) return;
      setState(() => _blocks.add(_DraftBlock(type, file.path)));
    } catch (error) {
      if (mounted) _showMessage('文件选择未完成：$error');
    }
  }

  void _moveBlock(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _blocks.length) return;
    setState(() {
      final block = _blocks.removeAt(index);
      _blocks.insert(target, block);
    });
  }

  void _removeBlock(int index) {
    setState(() {
      final block = _blocks.removeAt(index);
      block.dispose();
      if (_blocks.isEmpty) {
        _blocks.add(_DraftBlock(QuickNoteBlockType.text, ''));
      }
    });
  }

  Future<void> _save() async {
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
      _showMessage('请写入正文或插入一个附件');
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(quickNoteRepositoryProvider);
      if (widget.note == null) {
        await repository.createNote(
          title: _normalizedTitle,
          blocks: blocks,
          localDate: localDateKey(_selectedDate),
          tagIds: _selectedTagIds.toList(growable: false),
        );
      } else {
        await repository.updateNote(
          id: widget.note!.id,
          title: _normalizedTitle,
          blocks: blocks,
          localDate: localDateKey(_selectedDate),
          tagIds: _selectedTagIds.toList(growable: false),
        );
      }
      invalidateQuickNoteData(ref);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('操作未完成：$error');
      }
    }
  }

  String? get _normalizedTitle {
    final title = _titleController.text.trim();
    return title.isEmpty ? null : title;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ArticleToolbar extends StatelessWidget {
  const _ArticleToolbar({required this.onAdd});

  final ValueChanged<QuickNoteBlockType> onAdd;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ToolbarButton(
                key: const ValueKey('quick-note-add-text'),
                icon: Icons.text_fields,
                tooltip: '插入文字',
                onPressed: () => onAdd(QuickNoteBlockType.text),
              ),
              _ToolbarButton(
                key: const ValueKey('quick-note-add-image'),
                icon: Icons.image_outlined,
                tooltip: '插入图片',
                onPressed: () => onAdd(QuickNoteBlockType.image),
              ),
              _ToolbarButton(
                key: const ValueKey('quick-note-add-audio'),
                icon: Icons.mic_none_outlined,
                tooltip: '插入录音',
                onPressed: () => onAdd(QuickNoteBlockType.audio),
              ),
              _ToolbarButton(
                key: const ValueKey('quick-note-add-video'),
                icon: Icons.videocam_outlined,
                tooltip: '插入视频',
                onPressed: () => onAdd(QuickNoteBlockType.video),
              ),
              _ToolbarButton(
                key: const ValueKey('quick-note-add-link'),
                icon: Icons.link,
                tooltip: '插入链接',
                onPressed: () => onAdd(QuickNoteBlockType.link),
              ),
              _ToolbarButton(
                key: const ValueKey('quick-note-add-emoji'),
                icon: Icons.emoji_emotions_outlined,
                tooltip: '插入表情',
                onPressed: () => onAdd(QuickNoteBlockType.emoji),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon));
  }
}

class _ArticleBlockEditor extends StatelessWidget {
  const _ArticleBlockEditor({
    required this.block,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    super.key,
  });

  final _DraftBlock block;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _iconForType(block.type),
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                block.type.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: '上移',
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: '删除内容块',
                onPressed: onDelete,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          _BlockBody(block: block, index: index),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BlockBody extends StatelessWidget {
  const _BlockBody({required this.block, required this.index});

  final _DraftBlock block;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (block.type == QuickNoteBlockType.image &&
        block.controller.text.isNotEmpty) {
      final value = block.controller.text;
      final uri = Uri.tryParse(value);
      final isNetworkImage =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      final image = isNetworkImage
          ? Image.network(
              value,
              height: 280,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) =>
                  _AttachmentPreview(block: block),
            )
          : Image.file(
              File(value),
              height: 280,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) =>
                  _AttachmentPreview(block: block),
            );
      return ClipRRect(borderRadius: BorderRadius.circular(6), child: image);
    }
    if (_isFileBlock(block.type)) {
      return _AttachmentPreview(block: block);
    }
    final hint = switch (block.type) {
      QuickNoteBlockType.text => '开始写作...',
      QuickNoteBlockType.emoji => '输入表情',
      QuickNoteBlockType.link => '粘贴链接',
      _ => '',
    };
    return TextField(
      key: ValueKey('quick-note-block-$index'),
      controller: block.controller,
      minLines: block.type == QuickNoteBlockType.text ? 4 : 1,
      maxLines: null,
      keyboardType: block.type == QuickNoteBlockType.link
          ? TextInputType.url
          : TextInputType.multiline,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.block});

  final _DraftBlock block;

  @override
  Widget build(BuildContext context) {
    final value = block.controller.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            _iconForType(block.type),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? block.type.label : path.basename(value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isFileBlock(QuickNoteBlockType type) {
  return type == QuickNoteBlockType.image ||
      type == QuickNoteBlockType.audio ||
      type == QuickNoteBlockType.video;
}

String _dateLabel(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
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
