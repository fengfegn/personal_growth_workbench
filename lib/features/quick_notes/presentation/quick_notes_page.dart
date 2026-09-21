import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/quick_note_providers.dart';
import '../domain/quick_note.dart';
import 'quick_note_editor_page.dart';

class QuickNotesPage extends ConsumerStatefulWidget {
  const QuickNotesPage({super.key});

  @override
  ConsumerState<QuickNotesPage> createState() => _QuickNotesPageState();
}

class _QuickNotesPageState extends ConsumerState<QuickNotesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(quickNotesProvider);
    final tags = ref.watch(quickNoteTagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('随心记'),
        actions: [
          IconButton(
            tooltip: '新建标签',
            onPressed: _createTag,
            icon: const Icon(Icons.new_label_outlined),
          ),
          IconButton(
            tooltip: '显示已归档',
            onPressed: () => ref
                .read(includeArchivedQuickNotesProvider.notifier)
                .update((value) => !value),
            icon: Icon(
              ref.watch(includeArchivedQuickNotesProvider)
                  ? Icons.inventory_2
                  : Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('quick-note-create'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('新建文章'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                ref.read(quickNoteSearchProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: '搜索记录、内容或标签',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(quickNoteSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          tags.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Text('标签读取失败：$error'),
            data: (items) => _TagFilterBar(tags: items),
          ),
          const SizedBox(height: 20),
          notes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('读取记录失败：$error')),
            data: (items) => items.isEmpty
                ? const _EmptyNotesState()
                : _Timeline(
                    notes: items,
                    onEdit: (note) => _openEditor(context, note: note),
                    onChanged: _refresh,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {QuickNoteItem? note}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            QuickNoteEditorPage(initialDate: DateTime.now(), note: note),
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      _showMessage('文章已保存，本地数据已经保存');
    }
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标签名称'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await ref.read(quickNoteRepositoryProvider).createTag(name);
      invalidateQuickNoteData(ref);
      _showMessage('标签已创建');
    } catch (error) {
      _showMessage('操作未完成：$error');
    }
  }

  void _refresh() => invalidateQuickNoteData(ref);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TagFilterBar extends ConsumerWidget {
  const _TagFilterBar({required this.tags});

  final List<QuickNoteTagItem> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(quickNoteTagFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: selected == null,
            onSelected: (_) =>
                ref.read(quickNoteTagFilterProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          for (final tag in tags) ...[
            ChoiceChip(
              label: Text(tag.name),
              selected: selected == tag.id,
              onSelected: (_) =>
                  ref.read(quickNoteTagFilterProvider.notifier).state =
                      selected == tag.id ? null : tag.id,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.notes,
    required this.onEdit,
    required this.onChanged,
  });

  final List<QuickNoteItem> notes;
  final ValueChanged<QuickNoteItem> onEdit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<QuickNoteItem>>{};
    for (final note in notes) {
      groups.putIfAbsent(note.localDate, () => []).add(note);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _dateLabel(entry.key),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final note in entry.value)
            _NoteCard(note: note, onEdit: onEdit, onChanged: onChanged),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onChanged,
  });

  final QuickNoteItem note;
  final ValueChanged<QuickNoteItem> onEdit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(quickNoteRepositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (note.pinned)
                  Icon(
                    Icons.push_pin,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (note.pinned) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.title?.isNotEmpty == true ? note.title! : '无标题文章',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _timeLabel(note.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                PopupMenuButton<String>(
                  tooltip: '记录操作',
                  onSelected: (action) async {
                    switch (action) {
                      case 'pin':
                        await repository.togglePinned(note.id, !note.pinned);
                      case 'favorite':
                        await repository.toggleFavorite(
                          note.id,
                          !note.favorite,
                        );
                      case 'archive':
                        await repository.toggleArchived(
                          note.id,
                          !note.archived,
                        );
                      case 'delete':
                        await repository.softDelete(note.id);
                      case 'edit':
                        onEdit(note);
                        return;
                    }
                    onChanged();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: const Text('编辑')),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(note.pinned ? '取消置顶' : '置顶'),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Text(note.favorite ? '取消收藏' : '收藏'),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(note.archived ? '移出归档' : '归档'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            for (final tag in note.tags)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            for (final block in note.blocks) _NoteBlockView(block: block),
            if (note.favorite)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.favorite,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteBlockView extends StatelessWidget {
  const _NoteBlockView({required this.block});

  final QuickNoteContentBlock block;

  @override
  Widget build(BuildContext context) {
    final isText = block.type == QuickNoteBlockType.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForType(block.type),
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              block.value,
              style: isText ? null : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.edit_note_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('还没有随心记，先留下此刻的一点想法。'),
        ],
      ),
    );
  }
}

String _dateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final today = DateTime.now();
  final localToday = DateTime(today.year, today.month, today.day);
  final difference = date.difference(localToday).inDays;
  if (difference == 0) return '今天 · $value';
  if (difference == -1) return '昨天 · $value';
  return '${date.year}年${date.month}月${date.day}日';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
