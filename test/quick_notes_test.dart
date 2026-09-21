import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/quick_notes/data/quick_note_repository.dart';
import 'package:personal_growth_workbench/features/quick_notes/domain/quick_note.dart';
import 'package:personal_growth_workbench/features/quick_notes/presentation/quick_note_editor_page.dart';
import 'package:personal_growth_workbench/features/quick_notes/presentation/quick_notes_page.dart';

void main() {
  test(
    'stores multi-format quick notes with default tags and searches them',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = QuickNoteRepository(database);

      final tags = await repository.getTags();
      expect(tags.map((tag) => tag.name), QuickNoteRepository.defaultTagNames);
      final technicalTag = tags.firstWhere((tag) => tag.name == '技术知识');

      final note = await repository.createNote(
        title: '研究灵感',
        localDate: '2026-08-06',
        tagIds: [technicalTag.id],
        blocks: const [
          QuickNoteContentBlock(type: QuickNoteBlockType.text, value: '把问题拆小'),
          QuickNoteContentBlock(
            type: QuickNoteBlockType.image,
            value: 'idea.png',
          ),
          QuickNoteContentBlock(
            type: QuickNoteBlockType.audio,
            value: 'voice.m4a',
          ),
          QuickNoteContentBlock(
            type: QuickNoteBlockType.video,
            value: 'clip.mp4',
          ),
          QuickNoteContentBlock(type: QuickNoteBlockType.emoji, value: '💡'),
          QuickNoteContentBlock(
            type: QuickNoteBlockType.link,
            value: 'https://example.com',
          ),
        ],
      );

      expect(note.localDate, '2026-08-06');
      expect(note.blocks.length, 6);
      expect(note.tags, ['技术知识']);
      expect(
        (await repository.getNotes(search: 'idea.png')).single.id,
        note.id,
      );
      expect(
        (await repository.getNotes(tagId: technicalTag.id)).single.title,
        '研究灵感',
      );
      expect((await repository.getNotes(localDate: '2026-08-05')), isEmpty);

      await repository.toggleArchived(note.id, true);
      expect(await repository.getNotes(), isEmpty);
      expect(
        (await repository.getNotes(includeArchived: true)).single.archived,
        true,
      );
    },
  );

  test('migrates legacy default tags without losing note links', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = QuickNoteRepository(database);
    final legacyTag = await repository.createTag('思考');
    final note = await repository.createNote(
      title: '旧标签记录',
      localDate: '2026-08-06',
      tagIds: [legacyTag.id],
      blocks: const [
        QuickNoteContentBlock(type: QuickNoteBlockType.text, value: '保留原有关联'),
      ],
    );

    final tags = await repository.getTags();
    final migrated = await repository.getNote(note.id);

    expect(tags.map((tag) => tag.name), QuickNoteRepository.defaultTagNames);
    expect(tags.map((tag) => tag.name), isNot(contains('思考')));
    expect(migrated.tags, ['技术知识']);
  });

  test('orders the timeline by local date before pinned state', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = QuickNoteRepository(database);
    const block = QuickNoteContentBlock(
      type: QuickNoteBlockType.text,
      value: '时间线内容',
    );
    final older = await repository.createNote(
      title: '较早记录',
      localDate: '2026-08-05',
      blocks: const [block],
    );
    await repository.togglePinned(older.id, true);
    await repository.createNote(
      title: '最新记录',
      localDate: '2026-08-06',
      blocks: const [block],
    );

    final notes = await repository.getNotes();

    expect(notes.map((note) => note.title), ['最新记录', '较早记录']);
  });

  test('creates a custom tag without duplicating an existing name', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = QuickNoteRepository(database);

    final first = await repository.createTag('论文');
    final second = await repository.createTag('论文');

    expect(second.id, first.id);
    expect(
      (await repository.getTags()).where((tag) => tag.name == '论文').length,
      1,
    );
  });

  testWidgets('edits a memo article with inline attachment blocks', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = QuickNoteRepository(database);
    final note = await repository.createNote(
      title: '文章标题',
      localDate: '2026-08-06',
      blocks: const [
        QuickNoteContentBlock(type: QuickNoteBlockType.text, value: '正文段落'),
        QuickNoteContentBlock(
          type: QuickNoteBlockType.audio,
          value: 'recording.m4a',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: QuickNoteEditorPage(note: note)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('文章标题'), findsOneWidget);
    expect(find.text('recording.m4a'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-note-add-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-note-add-audio')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-note-add-text')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-block-2')),
      '新增段落',
    );
    await tester.tap(find.byKey(const ValueKey('quick-note-save')));
    await tester.pumpAndSettle();

    final saved = await repository.getNote(note.id);
    expect(saved.blocks.map((block) => block.value), [
      '正文段落',
      'recording.m4a',
      '新增段落',
    ]);
  });

  testWidgets('creates a timeline note from the quick notes page', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: QuickNotesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-note-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-title-field')),
      '页面记录',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quick-note-block-0')),
      '记录一段文字',
    );
    await tester.tap(find.widgetWithText(FilterChip, '技术知识'));
    await tester.tap(find.byKey(const ValueKey('quick-note-save')));
    await tester.pumpAndSettle();

    expect(find.text('页面记录'), findsOneWidget);
    expect(find.text('记录一段文字'), findsOneWidget);
    expect((await QuickNoteRepository(database).getNotes()).single.tags, [
      '技术知识',
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, '技术知识'));
    await tester.pumpAndSettle();
    expect(find.text('页面记录'), findsOneWidget);
  });
}
