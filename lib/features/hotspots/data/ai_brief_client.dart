import 'dart:convert';
import 'dart:io';

import '../domain/ai_brief_article.dart';
import '../domain/news_source.dart';

class AiBriefException implements Exception {
  const AiBriefException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiBriefClient {
  static const _listPath = '/fapigw/aibrief/list';
  static const _detailPath = '/fapigw/aibrief/detail';

  Future<List<AiBriefArticle>> fetchList(
    NewsSourceConfig source, {
    required String type,
  }) async {
    final uri = _endpoint(source.endpoint, _listPath).replace(
      queryParameters: {
        'key': source.apiKey.trim(),
        'type': type,
        'page': '${source.page}',
        'page_size': '${source.pageSize.clamp(1, 20)}',
      },
    );
    final decoded = await _getJson(uri);
    _ensureSuccess(decoded);
    final result = decoded['result'];
    final values = result is Map<String, dynamic> ? result['list'] : null;
    if (values == null) {
      return const [];
    }
    if (values is! List) {
      throw const AiBriefException(
        'AI brief list response has an invalid result.list field.',
      );
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(_articleFromJson)
        .where((article) => article.id.isNotEmpty && article.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<AiBriefArticle> fetchDetail(
    NewsSourceConfig source,
    AiBriefArticle article,
  ) async {
    final uri = _endpoint(
      source.endpoint,
      _detailPath,
    ).replace(queryParameters: {'key': source.apiKey.trim(), 'id': article.id});
    final decoded = await _getJson(uri);
    _ensureSuccess(decoded);
    final result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw const AiBriefException(
        'AI brief detail response has an invalid result field.',
      );
    }
    final detail = _articleFromJson(result);
    return detail.copyWith(content: _htmlToText(detail.content));
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    if (uri.queryParameters['key']?.isEmpty ?? true) {
      throw const AiBriefException(
        'The AI brief source has no API key in secure storage.',
      );
    }
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers
        ..contentType = ContentType('application', 'x-www-form-urlencoded')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiBriefException(
          'AI brief API returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiBriefException(
          'AI brief API did not return a JSON object.',
        );
      }
      return decoded;
    } on AiBriefException {
      rethrow;
    } on Object catch (error) {
      throw AiBriefException('AI brief request failed: $error');
    } finally {
      client.close(force: true);
    }
  }

  Uri _endpoint(String rawEndpoint, String expectedPath) {
    final uri = Uri.tryParse(rawEndpoint.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const AiBriefException(
        'AI brief source requires a valid HTTP or HTTPS endpoint.',
      );
    }
    return uri.replace(path: expectedPath, queryParameters: const {});
  }

  void _ensureSuccess(Map<String, dynamic> decoded) {
    final errorCode = decoded['error_code'];
    if (errorCode is num && errorCode == 0) {
      return;
    }
    final reason =
        decoded['reason'] as String? ?? 'Unknown AI brief API error.';
    throw AiBriefException('AI brief API error $errorCode: $reason');
  }

  AiBriefArticle _articleFromJson(Map<String, dynamic> json) {
    return AiBriefArticle(
      id: _text(json['id']),
      title: _text(json['title']),
      sourceName: _text(json['author_name']),
      type: _text(json['type']),
      imageUrl: _text(json['image_url']),
      summary: _text(json['summary']),
      publishedAt: DateTime.tryParse(_text(json['publish_date'])),
      url: _text(json['url']),
      content: _text(json['content']),
    );
  }

  String _text(dynamic value) => value is String ? value.trim() : '';

  String _htmlToText(String html) {
    return html
        .replaceAll(
          RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
