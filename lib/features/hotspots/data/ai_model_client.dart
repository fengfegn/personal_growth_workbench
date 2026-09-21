import 'dart:convert';
import 'dart:io';

import '../../ai/domain/ai_provider.dart';
import '../domain/hotspot.dart';
import '../domain/news_source.dart';

class AiModelException implements Exception {
  const AiModelException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AiModelClient {
  Future<List<NewsArticle>> selectTopArticles(List<NewsArticle> articles);

  Future<List<HotspotDraft>> summarize(List<NewsArticle> articles);
}

class OpenAiCompatibleClient implements AiModelClient {
  OpenAiCompatibleClient(this.settings);

  final AiProviderSettings settings;

  Future<void> verifyConnection() async {
    _ensureConfigured();
    await _complete(
      'You are a connection check. Reply with exactly OK.',
      'Reply with OK.',
    );
  }

  @override
  Future<List<NewsArticle>> selectTopArticles(
    List<NewsArticle> articles,
  ) async {
    _ensureConfigured();
    if (articles.isEmpty) {
      throw const AiModelException('没有可供筛选的新闻文章');
    }

    final content = await _complete(
      _selectionSystemPrompt,
      _titlePrompt(articles),
    );
    final decoded = jsonDecode(_extractJson(content));
    final values = decoded is Map<String, dynamic> ? decoded['urls'] : decoded;
    if (values is! List) {
      throw const AiModelException('大模型热点筛选结果格式无效');
    }

    final articlesByUrl = {
      for (final article in articles)
        if (article.url.isNotEmpty) article.url: article,
    };
    final selected = <NewsArticle>[];
    final seen = <String>{};
    for (final value in values.whereType<String>()) {
      final article = articlesByUrl[value.trim()];
      if (article != null && seen.add(article.url)) {
        selected.add(article);
      }
      if (selected.length == 10) {
        break;
      }
    }
    return selected;
  }

  @override
  Future<List<HotspotDraft>> summarize(List<NewsArticle> articles) async {
    _ensureConfigured();
    if (articles.isEmpty) {
      throw const AiModelException('没有可供总结的新闻文章');
    }
    final content = await _complete(
      '$_systemPrompt\n$_singleSourceAllowance',
      _articlePrompt(articles),
    );
    return _parseResponse(content, articles);
  }

  void _ensureConfigured() {
    if (!settings.isConfigured) {
      throw const AiModelException('请先在设置中配置并启用大模型 API');
    }
  }

  Future<String> _complete(String systemPrompt, String userPrompt) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(settings.config.endpoint));
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${settings.apiKey}');
      request.write(
        jsonEncode({
          'model': settings.config.model,
          'temperature': 0.2,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiModelException('大模型接口返回 HTTP ${response.statusCode}');
      }
      return _readContent(jsonDecode(body));
    } on AiModelException {
      rethrow;
    } on Object catch (error) {
      throw AiModelException('大模型请求失败：$error');
    } finally {
      client.close(force: true);
    }
  }

  List<HotspotDraft> _parseResponse(
    String content,
    List<NewsArticle> articles,
  ) {
    final parsed = jsonDecode(_extractJson(content));
    final values = parsed is Map<String, dynamic> ? parsed['items'] : parsed;
    if (values is! List) {
      throw const AiModelException('大模型返回格式无效');
    }

    final articlesByUrl = {
      for (final article in articles)
        if (article.url.isNotEmpty) article.url: article,
    };
    return values
        .whereType<Map<String, dynamic>>()
        .map((item) => _toDraft(item, articlesByUrl))
        .whereType<HotspotDraft>()
        .toList(growable: false);
  }

  HotspotDraft? _toDraft(
    Map<String, dynamic> item,
    Map<String, NewsArticle> articlesByUrl,
  ) {
    final sourceUrls = (item['sourceUrls'] as List?)
        ?.whereType<String>()
        .where(articlesByUrl.containsKey)
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sourceUrls == null || sourceUrls.isEmpty) {
      return null;
    }
    final category = _categoryFromValue(item['category'] as String? ?? '');
    final title = item['title'] as String?;
    final summary = item['summary'] as String?;
    final analysis = item['analysis'] as String? ?? summary;
    if (title == null ||
        title.trim().isEmpty ||
        summary == null ||
        summary.trim().isEmpty ||
        analysis == null ||
        analysis.trim().isEmpty) {
      return null;
    }
    final keyPoints =
        (item['keyPoints'] as List?)
            ?.whereType<String>()
            .where((point) => point.trim().isNotEmpty)
            .map((point) => point.trim())
            .take(5)
            .toList(growable: false) ??
        const <String>[];
    final parsedConfidence = HotspotConfidence.values.firstWhere(
      (value) => value.name == item['confidence'],
      orElse: () => HotspotConfidence.medium,
    );
    final confidence = sourceUrls.length == 1
        ? HotspotConfidence.low
        : parsedConfidence;
    return HotspotDraft(
      category: category,
      title: title.trim(),
      summary: summary.trim(),
      analysis: analysis.trim(),
      keyPoints: keyPoints,
      sources: [
        for (final url in sourceUrls)
          HotspotSource(
            name: articlesByUrl[url]!.sourceName,
            url: url,
            publishedAt: articlesByUrl[url]!.publishedAt,
          ),
      ],
      confidence: confidence,
    );
  }

  HotspotCategory _categoryFromValue(String value) {
    final normalized = value.trim().toLowerCase();
    return HotspotCategory.values.firstWhere(
      (category) =>
          category.name == normalized ||
          category.label == value.trim() ||
          (category == HotspotCategory.policy && normalized == 'politics') ||
          (category == HotspotCategory.finance && normalized == 'economy') ||
          (category == HotspotCategory.technology && normalized == 'tech'),
      orElse: () => HotspotCategory.policy,
    );
  }

  String _readContent(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const AiModelException('大模型响应不是 JSON 对象');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiModelException('大模型响应缺少 choices');
    }
    final message = choices.first is Map<String, dynamic>
        ? choices.first['message']
        : null;
    final content = message is Map<String, dynamic> ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiModelException('大模型响应缺少文本内容');
    }
    return content.trim();
  }

  String _extractJson(String content) {
    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
    ).firstMatch(content);
    if (fenced != null) {
      return fenced.group(1)!.trim();
    }
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return content.substring(start, end + 1);
    }
    final listStart = content.indexOf('[');
    final listEnd = content.lastIndexOf(']');
    if (listStart >= 0 && listEnd > listStart) {
      return content.substring(listStart, listEnd + 1);
    }
    throw const AiModelException('大模型没有返回可解析的 JSON');
  }

  String _articlePrompt(List<NewsArticle> articles) {
    final buffer = StringBuffer();
    for (var index = 0; index < articles.length && index < 10; index++) {
      final article = articles[index];
      buffer
        ..writeln('ARTICLE $index')
        ..writeln('SOURCE: ${article.sourceName}')
        ..writeln('URL: ${article.url}')
        ..writeln('TITLE: ${article.title}')
        ..writeln(
          'CONTENT: ${_limit(article.content.isNotEmpty ? article.content : article.summary, 3000)}',
        )
        ..writeln();
    }
    return buffer.toString();
  }

  String _titlePrompt(List<NewsArticle> articles) {
    final buffer = StringBuffer();
    for (var index = 0; index < articles.length; index++) {
      final article = articles[index];
      buffer
        ..writeln('ARTICLE $index')
        ..writeln('URL: ${article.url}')
        ..writeln('SOURCE: ${article.sourceName}')
        ..writeln('TITLE: ${article.title}')
        ..writeln();
    }
    return buffer.toString();
  }

  String _limit(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  static const _selectionSystemPrompt = '''
你是每日热点筛选编辑。只根据新闻标题判断重要性，从输入的全部文章中筛选最多 10 条当天最值得关注的国家政策、财经、科技、外交新闻。
优先选择影响范围大、事实明确、时效性强且彼此不重复的标题。只返回 JSON，不要 Markdown，格式：{"urls":["输入文章中的完整 URL"]}。
''';

  static const _systemPrompt = '''
你是每日热点分析编辑。只处理国家政策、财经、科技、外交四类信息。
请对文章去重、交叉验证，只把至少两个不同 URL 或来源共同支持的事实写入结果；不要推测，不要把评论当事实。
summary 只写已核实事实，analysis 给出克制、基于事实的理性影响分析，明确区分事实与判断，不做投资或外交行动建议。
仅返回 JSON，不要 Markdown。格式：
{"items":[{"category":"policy|finance|technology|diplomacy","title":"...","summary":"...","analysis":"...","keyPoints":["..."],"sourceUrls":["...","..."],"confidence":"high|medium|low"}]}
''';

  static const _singleSourceAllowance = '''
When the supplied material contains only one article for a relevant event,
you may return that event with exactly one source URL and confidence "low".
Do not invent a second URL. Clearly keep the summary grounded in the article.
Exclude entertainment, celebrity gossip, lifestyle gossip, and promotional
content. Keep only technology, finance, or consequential world affairs.
''';
}
