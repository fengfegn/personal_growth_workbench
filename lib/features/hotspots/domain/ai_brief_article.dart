class AiBriefArticle {
  const AiBriefArticle({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.type,
    required this.imageUrl,
    required this.summary,
    required this.publishedAt,
    required this.url,
    this.content = '',
  });

  final String id;
  final String title;
  final String sourceName;
  final String type;
  final String imageUrl;
  final String summary;
  final DateTime? publishedAt;
  final String url;
  final String content;

  AiBriefArticle copyWith({String? content}) {
    return AiBriefArticle(
      id: id,
      title: title,
      sourceName: sourceName,
      type: type,
      imageUrl: imageUrl,
      summary: summary,
      publishedAt: publishedAt,
      url: url,
      content: content ?? this.content,
    );
  }

  factory AiBriefArticle.fromJson(Map<String, dynamic> json) {
    return AiBriefArticle(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      type: json['type'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      url: json['url'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceName': sourceName,
    'type': type,
    'imageUrl': imageUrl,
    'summary': summary,
    'publishedAt': publishedAt?.toIso8601String(),
    'url': url,
    'content': content,
  };
}
