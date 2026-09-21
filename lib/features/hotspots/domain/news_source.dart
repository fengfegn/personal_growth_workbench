enum NewsResponseType {
  json('JSON'),
  rss('RSS'),
  text('纯文本');

  const NewsResponseType(this.label);

  final String label;

  static NewsResponseType fromStorage(String? value) {
    return NewsResponseType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => NewsResponseType.json,
    );
  }
}

enum NewsApiKeyLocation {
  auto('Auto'),
  bearer('Authorization Bearer'),
  query('URL query parameter');

  const NewsApiKeyLocation(this.label);

  final String label;

  static NewsApiKeyLocation fromStorage(String? value) {
    return NewsApiKeyLocation.values.firstWhere(
      (location) => location.name == value,
      orElse: () => NewsApiKeyLocation.auto,
    );
  }
}

class NewsSourceConfig {
  const NewsSourceConfig({
    this.id = '',
    required this.name,
    required this.endpoint,
    this.apiKey = '',
    this.responseType = NewsResponseType.json,
    this.apiKeyLocation = NewsApiKeyLocation.auto,
    this.apiKeyParameter = 'key',
    this.enabled = true,
    this.page = 1,
    this.pageSize = 10,
  });

  factory NewsSourceConfig.fromJson(Map<String, dynamic> json) {
    return NewsSourceConfig(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      endpoint: (json['endpoint'] as String?)?.trim() ?? '',
      responseType: NewsResponseType.fromStorage(
        json['responseType'] as String?,
      ),
      apiKeyLocation: NewsApiKeyLocation.fromStorage(
        json['apiKeyLocation'] as String?,
      ),
      apiKeyParameter:
          (json['apiKeyParameter'] as String?)?.trim().isNotEmpty == true
          ? (json['apiKeyParameter'] as String).trim()
          : 'key',
      enabled: json['enabled'] as bool? ?? true,
      page: _readPositiveInt(json['page'], fallback: 1),
      pageSize: _readPositiveInt(json['pageSize'], fallback: 10),
    );
  }

  final String id;
  final String name;
  final String endpoint;
  final String apiKey;
  final NewsResponseType responseType;
  final NewsApiKeyLocation apiKeyLocation;
  final String apiKeyParameter;
  final bool enabled;
  final int page;
  final int pageSize;

  NewsSourceConfig copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? apiKey,
    NewsResponseType? responseType,
    NewsApiKeyLocation? apiKeyLocation,
    String? apiKeyParameter,
    bool? enabled,
    int? page,
    int? pageSize,
  }) {
    return NewsSourceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      responseType: responseType ?? this.responseType,
      apiKeyLocation: apiKeyLocation ?? this.apiKeyLocation,
      apiKeyParameter: apiKeyParameter ?? this.apiKeyParameter,
      enabled: enabled ?? this.enabled,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'responseType': responseType.name,
    'apiKeyLocation': apiKeyLocation.name,
    'apiKeyParameter': apiKeyParameter,
    'enabled': enabled,
    'page': page,
    'pageSize': pageSize,
  };
}

int _readPositiveInt(dynamic value, {required int fallback}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : fallback;
}

class NewsArticle {
  const NewsArticle({
    required this.sourceName,
    required this.title,
    required this.summary,
    required this.url,
    required this.publishedAt,
    this.content = '',
  });

  final String sourceName;
  final String title;
  final String summary;
  final String url;
  final DateTime? publishedAt;
  final String content;

  NewsArticle copyWith({String? content, String? summary}) => NewsArticle(
    sourceName: sourceName,
    title: title,
    summary: summary ?? this.summary,
    url: url,
    publishedAt: publishedAt,
    content: content ?? this.content,
  );
}
