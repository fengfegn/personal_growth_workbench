import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/quick_note.dart';

class QuickNoteRepository {
  QuickNoteRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();
  static const defaultTagNames = ['灵感', '吐槽', '技术知识', '日记', '会议记录'];
  static const _legacyDefaultTagNames = {'思考': '技术知识', '胡斯乱想': '会议记录'};
  Future<void>? _defaultTagsFuture;

  Future<List<QuickNoteItem>> getNotes({
    String? localDate,
    String? localMonth,
    String? search,
    String? tagId,
    bool includeArchived = false,
  }) async {
    await ensureDefaultTags();
    final query = _database.select(_database.quickNotes)
      ..where((note) {
        final conditions = <Expression<bool>>[note.deletedAt.isNull()];
        if (!includeArchived) conditions.add(note.archived.equals(false));
        if (localDate != null) conditions.add(note.localDate.equals(localDate));
        if (localMonth != null) {
          conditions.add(note.localDate.like('$localMonth-%'));
        }
        if (tagId != null) {
          conditions.add(
            existsQuery(
              _database.select(_database.quickNoteTagLinks)..where(
                (link) =>
                    link.noteId.equalsExp(note.id) &
                    link.tagId.equals(tagId) &
                    link.deletedAt.isNull(),
              ),
            ),
          );
        }
        return conditions.reduce((first, second) => first & second);
      })
      ..orderBy([
        (note) =>
            OrderingTerm(expression: note.localDate, mode: OrderingMode.desc),
        (note) =>
            OrderingTerm(expression: note.pinned, mode: OrderingMode.desc),
        (note) =>
            OrderingTerm(expression: note.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    final notes = <QuickNoteItem>[];
    for (final row in rows) {
      notes.add(await _mapRow(row));
    }
    if (search == null || search.trim().isEmpty) return notes;
    final keyword = search.trim().toLowerCase();
    return notes
        .where((note) => note.searchableText.toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  Future<QuickNoteItem> createNote({
    String? title,
    required List<QuickNoteContentBlock> blocks,
    required String localDate,
    List<String> tagIds = const [],
  }) async {
    final normalizedBlocks = blocks
        .where((block) => block.value.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedBlocks.isEmpty) {
      throw ArgumentError('记录内容不能为空');
    }
    final now = DateTime.now().toUtc();
    final noteId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.quickNotes)
          .insert(
            QuickNotesCompanion.insert(
              id: noteId,
              title: Value(_normalizedText(title)),
              contentJson: QuickNoteItem.encodeBlocks(normalizedBlocks),
              localDate: localDate,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceBlocks(noteId, normalizedBlocks, now);
      await _replaceTags(noteId, tagIds, now);
    });
    return getNote(noteId);
  }

  Future<QuickNoteItem> updateNote({
    required String id,
    String? title,
    required List<QuickNoteContentBlock> blocks,
    required String localDate,
    List<String> tagIds = const [],
  }) async {
    final normalizedBlocks = blocks
        .where((block) => block.value.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedBlocks.isEmpty) {
      throw ArgumentError('记录内容不能为空');
    }
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await (_database.update(
        _database.quickNotes,
      )..where((note) => note.id.equals(id))).write(
        QuickNotesCompanion(
          title: Value(_normalizedText(title)),
          contentJson: Value(QuickNoteItem.encodeBlocks(normalizedBlocks)),
          localDate: Value(localDate),
          updatedAt: Value(now),
        ),
      );
      await (_database.delete(
        _database.quickNoteBlocks,
      )..where((block) => block.noteId.equals(id))).go();
      await (_database.delete(
        _database.quickNoteTagLinks,
      )..where((link) => link.noteId.equals(id))).go();
      await _replaceBlocks(id, normalizedBlocks, now);
      await _replaceTags(id, tagIds, now);
    });
    return getNote(id);
  }

  Future<QuickNoteItem> getNote(String id) async {
    final row = await (_database.select(
      _database.quickNotes,
    )..where((note) => note.id.equals(id))).getSingle();
    return _mapRow(row);
  }

  Future<List<QuickNoteTagItem>> getTags() async {
    await ensureDefaultTags();
    final rows =
        await (_database.select(_database.quickNoteTags)
              ..where((tag) => tag.deletedAt.isNull())
              ..orderBy([(tag) => OrderingTerm(expression: tag.createdAt)]))
            .get();
    rows.sort((first, second) {
      final firstIndex = defaultTagNames.indexOf(first.name);
      final secondIndex = defaultTagNames.indexOf(second.name);
      if (firstIndex >= 0 && secondIndex >= 0) {
        return firstIndex.compareTo(secondIndex);
      }
      if (firstIndex >= 0) return -1;
      if (secondIndex >= 0) return 1;
      final createdAtComparison = first.createdAt.compareTo(second.createdAt);
      return createdAtComparison != 0
          ? createdAtComparison
          : first.name.compareTo(second.name);
    });
    return rows
        .map((row) => QuickNoteTagItem(id: row.id, name: row.name))
        .toList(growable: false);
  }

  Future<QuickNoteTagItem> createTag(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('标签名称不能为空');
    final existing =
        await (_database.select(_database.quickNoteTags)
              ..where(
                (tag) => tag.name.equals(normalized) & tag.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return QuickNoteTagItem(id: existing.id, name: existing.name);
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.quickNoteTags)
        .insert(
          QuickNoteTagsCompanion.insert(
            id: id,
            name: normalized,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return QuickNoteTagItem(id: id, name: normalized);
  }

  Future<void> ensureDefaultTags() async {
    final existing = _defaultTagsFuture;
    if (existing != null) return existing;
    final future = _seedDefaultTags();
    _defaultTagsFuture = future;
    return future;
  }

  Future<void> _seedDefaultTags() async {
    await _migrateLegacyDefaultTags();
    for (final name in defaultTagNames) {
      await createTag(name);
    }
  }

  Future<void> _migrateLegacyDefaultTags() async {
    await _database.transaction(() async {
      for (final entry in _legacyDefaultTagNames.entries) {
        final legacy =
            await (_database.select(_database.quickNoteTags)
                  ..where(
                    (tag) =>
                        tag.name.equals(entry.key) & tag.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (legacy == null) continue;

        final replacement =
            await (_database.select(_database.quickNoteTags)
                  ..where(
                    (tag) =>
                        tag.name.equals(entry.value) & tag.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        final now = DateTime.now().toUtc();
        if (replacement == null) {
          await (_database.update(
            _database.quickNoteTags,
          )..where((tag) => tag.id.equals(legacy.id))).write(
            QuickNoteTagsCompanion(
              name: Value(entry.value),
              updatedAt: Value(now),
            ),
          );
          continue;
        }

        final links =
            await (_database.select(_database.quickNoteTagLinks)..where(
                  (link) =>
                      link.tagId.equals(legacy.id) & link.deletedAt.isNull(),
                ))
                .get();
        for (final link in links) {
          final replacementLink =
              await (_database.select(_database.quickNoteTagLinks)
                    ..where(
                      (candidate) =>
                          candidate.noteId.equals(link.noteId) &
                          candidate.tagId.equals(replacement.id) &
                          candidate.deletedAt.isNull(),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          await (_database.update(
            _database.quickNoteTagLinks,
          )..where((candidate) => candidate.id.equals(link.id))).write(
            QuickNoteTagLinksCompanion(
              tagId: replacementLink == null
                  ? Value(replacement.id)
                  : const Value.absent(),
              deletedAt: replacementLink == null
                  ? const Value.absent()
                  : Value(now),
              updatedAt: Value(now),
            ),
          );
        }
        await (_database.update(
          _database.quickNoteTags,
        )..where((tag) => tag.id.equals(legacy.id))).write(
          QuickNoteTagsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<void> togglePinned(String id, bool value) =>
      _setFlag(id, QuickNotesCompanion(pinned: Value(value)));

  Future<void> toggleFavorite(String id, bool value) =>
      _setFlag(id, QuickNotesCompanion(favorite: Value(value)));

  Future<void> toggleArchived(String id, bool value) =>
      _setFlag(id, QuickNotesCompanion(archived: Value(value)));

  Future<void> softDelete(String id) async {
    await _setFlag(
      id,
      QuickNotesCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<QuickNoteItem> _mapRow(QuickNote row) async {
    final blocks =
        await (_database.select(_database.quickNoteBlocks)
              ..where(
                (block) =>
                    block.noteId.equals(row.id) & block.deletedAt.isNull(),
              )
              ..orderBy([(block) => OrderingTerm(expression: block.sortOrder)]))
            .get();
    final links =
        await (_database.select(_database.quickNoteTagLinks)..where(
              (link) => link.noteId.equals(row.id) & link.deletedAt.isNull(),
            ))
            .get();
    final tagRows =
        await (_database.select(_database.quickNoteTags)..where(
              (tag) =>
                  tag.id.isIn(links.map((link) => link.tagId).toList()) &
                  tag.deletedAt.isNull(),
            ))
            .get();
    return QuickNoteItem.fromRow(
      row: row,
      blocks: blocks.isEmpty
          ? QuickNoteItem.decodeBlocks(row.contentJson)
          : blocks
                .map(
                  (block) => QuickNoteContentBlock(
                    type: quickNoteBlockTypeFromStorage(block.blockType),
                    value: block.value,
                  ),
                )
                .toList(growable: false),
      tags: tagRows.map((tag) => tag.name).toList(growable: false),
    );
  }

  Future<void> _replaceBlocks(
    String noteId,
    List<QuickNoteContentBlock> blocks,
    DateTime now,
  ) async {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      await _database
          .into(_database.quickNoteBlocks)
          .insert(
            QuickNoteBlocksCompanion.insert(
              id: _uuid.v4(),
              noteId: noteId,
              blockType: block.type.name,
              value: block.value.trim(),
              sortOrder: index,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _replaceTags(
    String noteId,
    List<String> tagIds,
    DateTime now,
  ) async {
    for (final tagId in tagIds.toSet()) {
      await _database
          .into(_database.quickNoteTagLinks)
          .insert(
            QuickNoteTagLinksCompanion.insert(
              id: _uuid.v4(),
              noteId: noteId,
              tagId: tagId,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _setFlag(String id, QuickNotesCompanion values) async {
    await (_database.update(_database.quickNotes)
          ..where((note) => note.id.equals(id)))
        .write(values.copyWith(updatedAt: Value(DateTime.now().toUtc())));
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
