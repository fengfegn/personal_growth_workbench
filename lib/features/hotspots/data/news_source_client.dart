import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../domain/news_source.dart';

class NewsSourceException implements Exception {
  const NewsSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsSourceClient {
  Future<List<NewsArticle>> fetch(NewsSourceConfig config) async {
    if (config.endpoint.trim().isEmpty) {
      throw NewsSourceException('${config.name} 尚未配置接口地址');
    }

    final uri = Uri.tryParse(config.endpoint);
    if (uri == null || !uri.hasScheme) {
      throw NewsSourceException('${config.name} 的接口地址无效');
    }
    final apiKey = config.apiKey.trim();
    final usesQueryKey = apiKey.isNotEmpty && _usesQueryKey(config, uri);
    final requestUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'page': '${config.page}',
        'num': '${config.pageSize}',
        if (usesQueryKey) config.apiKeyParameter.trim(): apiKey,
      },
    );

    final client = HttpClient();
    try {
      final request = await client
          .getUrl(requestUri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, _acceptHeader(config));
      if (apiKey.isNotEmpty && !usesQueryKey) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NewsSourceException(
          '${config.name} 接口返回 HTTP ${response.statusCode}',
        );
      }
      return _parseArticles(config, requestUri.toString(), body);
    } on NewsSourceException {
      rethrow;
    } on Object catch (error) {
      throw NewsSourceException('${config.name} 请求失败：$error');
    } finally {
      client.close(force: true);
    }
  }

  List<NewsArticle> _parseArticles(
    NewsSourceConfig config,
    String fallbackUrl,
    String body,
  ) {
    return switch (config.responseType) {
      NewsResponseType.json => _parseJsonArticles(
        config.name,
        fallbackUrl,
        body,
      ),
      NewsResponseType.rss => _parseRssArticles(config.name, fallbackUrl, body),
      NewsResponseType.text => _parseTextArticles(
        config.name,
        fallbackUrl,
        body,
      ),
    };
  }

  List<NewsArticle> _parseJsonArticles(
    String sourceName,
    String fallbackUrl,
    String body,
  ) {
    final decoded = jsonDecode(body);
    final values = _findArticleList(decoded);
    if (values is! List) {
      throw NewsSourceException('$sourceName 接口未返回文章列表');
    }

    return _articlesFromMaps(sourceName, fallbackUrl, values);
  }

  List<NewsArticle> _articlesFromMaps(
    String sourceName,
    String fallbackUrl,
    List<dynamic> values,
  ) {
    return values
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => NewsArticle(
            sourceName: (item['source'] as String?)?.trim().isNotEmpty == true
                ? (item['source'] as String).trim()
                : sourceName,
            title: _readText(item, ['title', 'name']),
            summary: _readText(item, ['summary', 'description', 'content']),
            url: _readText(item, ['url', 'link']).isNotEmpty
                ? _readText(item, ['url', 'link'])
                : fallbackUrl,
            publishedAt: DateTime.tryParse(
              _readText(item, ['publishedAt', 'published_at', 'date', 'ctime']),
            ),
          ),
        )
        .where((article) => article.title.isNotEmpty)
        .toList(growable: false);
  }

  List<dynamic>? _findArticleList(dynamic decoded) {
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    for (final key in const ['articles', 'data', 'results', 'newslist']) {
      final value = decoded[key];
      if (value is List) {
        return value;
      }
    }
    final result = decoded['result'];
    if (result is Map<String, dynamic>) {
      return _findArticleList(result);
    }
    return null;
  }

  List<NewsArticle> _parseRssArticles(
    String sourceName,
    String fallbackUrl,
    String body,
  ) {
    final document = XmlDocument.parse(body);
    final entries = document.descendants
        .whereType<XmlElement>()
        .where(
          (element) =>
              element.localName == 'item' || element.localName == 'entry',
        )
        .toList(growable: false);
    if (entries.isEmpty) {
      throw NewsSourceException('$sourceName 接口未返回 RSS 文章列表');
    }

    return entries
        .map(
          (entry) => NewsArticle(
            sourceName: sourceName,
            title: _elementText(entry, const ['title']),
            summary: _elementText(entry, const [
              'description',
              'summary',
              'content',
            ]),
            url: _linkText(entry, fallbackUrl),
            publishedAt: DateTime.tryParse(
              _elementText(entry, const ['pubDate', 'published', 'updated']),
            ),
          ),
        )
        .where((article) => article.title.isNotEmpty)
        .toList(growable: false);
  }

  List<NewsArticle> _parseTextArticles(
    String sourceName,
    String fallbackUrl,
    String body,
  ) {
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw NewsSourceException('$sourceName 接口未返回文本内容');
    }
    return [
      NewsArticle(
        sourceName: sourceName,
        title: lines.first,
        summary: lines.length > 1 ? lines.skip(1).join(' ') : lines.first,
        url: fallbackUrl,
        publishedAt: null,
      ),
    ];
  }

  String _elementText(
    XmlElement parent,
    List<String> names, {
    String? attribute,
  }) {
    for (final name in names) {
      XmlElement? element;
      for (final candidate in parent.descendants.whereType<XmlElement>()) {
        if (candidate.localName == name) {
          element = candidate;
          break;
        }
      }
      if (element == null) {
        continue;
      }
      final value = attribute == null
          ? element.innerText.trim()
          : (element.getAttribute(attribute) ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _linkText(XmlElement entry, String fallbackUrl) {
    final href = _elementText(entry, const ['link'], attribute: 'href');
    if (href.isNotEmpty) {
      return href;
    }
    final text = _elementText(entry, const ['link']);
    return text.isNotEmpty ? text : fallbackUrl;
  }

  String _acceptHeader(NewsSourceConfig config) {
    return switch (config.responseType) {
      NewsResponseType.json => 'application/json',
      NewsResponseType.rss =>
        'application/rss+xml, application/atom+xml, application/xml',
      NewsResponseType.text => 'text/plain, text/*;q=0.9',
    };
  }

  bool _usesQueryKey(NewsSourceConfig config, Uri uri) {
    return switch (config.apiKeyLocation) {
      NewsApiKeyLocation.query => true,
      NewsApiKeyLocation.bearer => false,
      NewsApiKeyLocation.auto =>
        uri.queryParameters.containsKey(config.apiKeyParameter.trim()) ||
            _usesKnownQueryKeyHost(uri.host),
    };
  }

  bool _usesKnownQueryKeyHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'tianapi.com' ||
        normalized.endsWith('.tianapi.com') ||
        normalized == 'juhe.cn' ||
        normalized.endsWith('.juhe.cn');
  }

  String _readText(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
