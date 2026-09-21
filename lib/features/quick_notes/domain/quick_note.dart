import 'dart:convert';

import '../../../core/database/app_database.dart';

enum QuickNoteBlockType {
  text('文本'),
  image('图片'),
  audio('录音'),
  video('视频'),
  emoji('表情'),
  link('链接');

  const QuickNoteBlockType(this.label);

  final String label;
}

QuickNoteBlockType quickNoteBlockTypeFromStorage(String value) {
  return QuickNoteBlockType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => QuickNoteBlockType.text,
  );
}

class QuickNoteContentBlock {
  const QuickNoteContentBlock({required this.type, required this.value});

  final QuickNoteBlockType type;
  final String value;

  Map<String, String> toJson() => {'type': type.name, 'value': value};

  factory QuickNoteContentBlock.fromJson(Map<String, dynamic> json) {
    return QuickNoteContentBlock(
      type: quickNoteBlockTypeFromStorage(json['type'] as String? ?? 'text'),
      value: json['value'] as String? ?? '',
    );
  }
}

class QuickNoteItem {
  const QuickNoteItem({
    required this.id,
    required this.title,
    required this.localDate,
    required this.blocks,
    required this.tags,
    required this.pinned,
    required this.favorite,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final String localDate;
  final List<QuickNoteContentBlock> blocks;
  final List<String> tags;
  final bool pinned;
  final bool favorite;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get preview {
    final visible = blocks
        .map(
          (block) => block.type == QuickNoteBlockType.text
              ? block.value
              : '${block.type.label}：${block.value}',
        )
        .where((value) => value.trim().isNotEmpty)
        .join('  ');
    return visible.isEmpty ? '空记录' : visible;
  }

  String get searchableText => [title ?? '', preview, ...tags].join(' ');

  static List<QuickNoteContentBlock> decodeBlocks(String contentJson) {
    try {
      final raw = jsonDecode(contentJson);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map(
              (item) => QuickNoteContentBlock.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      }
    } on FormatException {
      // A malformed old record remains readable as a text block.
    }
    return [
      QuickNoteContentBlock(type: QuickNoteBlockType.text, value: contentJson),
    ];
  }

  static String encodeBlocks(List<QuickNoteContentBlock> blocks) {
    return jsonEncode(blocks.map((block) => block.toJson()).toList());
  }

  factory QuickNoteItem.fromRow({
    required QuickNote row,
    required List<QuickNoteContentBlock> blocks,
    required List<String> tags,
  }) {
    return QuickNoteItem(
      id: row.id,
      title: row.title,
      localDate: row.localDate,
      blocks: List.unmodifiable(blocks),
      tags: List.unmodifiable(tags),
      pinned: row.pinned,
      favorite: row.favorite,
      archived: row.archived,
      createdAt: row.createdAt.toLocal(),
      updatedAt: row.updatedAt.toLocal(),
    );
  }
}

class QuickNoteTagItem {
  const QuickNoteTagItem({required this.id, required this.name});

  final String id;
  final String name;
}
