import 'package:personal_growth_workbench/core/database/app_database.dart';

enum HotspotCategory {
  policy('国家政策'),
  finance('财经'),
  technology('科技'),
  diplomacy('外交');

  const HotspotCategory(this.label);

  final String label;

  static HotspotCategory fromStorage(String value) {
    return HotspotCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => HotspotCategory.policy,
    );
  }
}

enum HotspotConfidence { high, medium, low }

class HotspotDigest {
  const HotspotDigest({
    required this.id,
    required this.localDate,
    required this.category,
    required this.title,
    required this.summary,
    required this.analysis,
    required this.keyPoints,
    required this.sources,
    required this.confidence,
    required this.provider,
    required this.model,
    required this.generatedAt,
  });

  factory HotspotDigest.fromRow(
    DailyHotspot row, {
    required List<String> keyPoints,
    required List<HotspotSource> sources,
  }) {
    return HotspotDigest(
      id: row.id,
      localDate: row.localDate,
      category: HotspotCategory.fromStorage(row.category),
      title: row.title,
      summary: row.summary,
      analysis: row.analysis,
      keyPoints: keyPoints,
      sources: sources,
      confidence: HotspotConfidence.values.firstWhere(
        (value) => value.name == row.confidence,
        orElse: () => HotspotConfidence.medium,
      ),
      provider: row.provider,
      model: row.model,
      generatedAt: row.generatedAt,
    );
  }

  final String id;
  final String localDate;
  final HotspotCategory category;
  final String title;
  final String summary;
  final String analysis;
  final List<String> keyPoints;
  final List<HotspotSource> sources;
  final HotspotConfidence confidence;
  final String? provider;
  final String? model;
  final DateTime generatedAt;
}

class HotspotSource {
  const HotspotSource({
    required this.name,
    required this.url,
    required this.publishedAt,
  });

  factory HotspotSource.fromJson(Map<String, dynamic> json) {
    final publishedAt = DateTime.tryParse(json['publishedAt'] as String? ?? '');
    return HotspotSource(
      name: json['name'] as String? ?? '未知来源',
      url: json['url'] as String? ?? '',
      publishedAt: publishedAt,
    );
  }

  final String name;
  final String url;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'publishedAt': publishedAt?.toIso8601String(),
  };
}

class HotspotDraft {
  const HotspotDraft({
    required this.category,
    required this.title,
    required this.summary,
    this.analysis = '',
    required this.keyPoints,
    required this.sources,
    required this.confidence,
  });

  final HotspotCategory category;
  final String title;
  final String summary;
  final String analysis;
  final List<String> keyPoints;
  final List<HotspotSource> sources;
  final HotspotConfidence confidence;
}
