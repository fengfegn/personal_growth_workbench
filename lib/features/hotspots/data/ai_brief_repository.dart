import '../../ai/data/ai_settings_repository.dart';
import '../application/hotspot_article_filter.dart';
import '../domain/ai_brief_article.dart';
import '../domain/news_source.dart';
import 'ai_brief_cache_repository.dart';
import 'ai_brief_client.dart';
import 'ai_model_client.dart';
import 'news_source_settings_repository.dart';

class AiBriefRepository {
  AiBriefRepository(
    this._sourceRepository, {
    AiBriefClient? client,
    required this._aiSettingsRepository,
    required this._cacheRepository,
  }) : _client = client ?? AiBriefClient();

  final NewsSourceSettingsRepository _sourceRepository;
  final AiBriefClient _client;
  final AiSettingsRepository _aiSettingsRepository;
  final AiBriefCacheRepository _cacheRepository;

  Future<List<AiBriefArticle>> getCachedArticles() {
    return _cacheRepository.getCachedArticles();
  }

  Future<List<AiBriefArticle>> refreshArticles() async {
    final source = await _source();
    await _cacheRepository.reserveRequests(3);
    final lists = await Future.wait([
      _client.fetchList(source, type: 'tech'),
      _client.fetchList(source, type: 'money'),
      _client.fetchList(source, type: 'hot'),
    ]);
    final byId = <String, AiBriefArticle>{
      for (final article in lists.expand((articles) => articles))
        article.id: article,
    };
    final localCandidates = HotspotArticleFilter.keepRelevant([
      for (final article in byId.values)
        NewsArticle(
          sourceName: article.sourceName,
          title: article.title,
          summary: article.summary,
          url: article.id,
          publishedAt: article.publishedAt,
        ),
    ]).map((article) => byId[article.url]!).toList(growable: false);
    final articles = await _filterWithAi(localCandidates);
    articles.sort(
      (left, right) =>
          (right.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                left.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
    );
    await _cacheRepository.saveCachedArticles(articles);
    return articles;
  }

  Future<AiBriefArticle> fetchDetail(AiBriefArticle article) async {
    if (article.content.isNotEmpty) {
      return article;
    }
    await _cacheRepository.reserveRequests(1);
    final detail = await _client.fetchDetail(await _source(), article);
    await _cacheRepository.updateCachedArticle(detail);
    return detail;
  }

  Future<NewsSourceConfig> _source() async {
    final sources = await _sourceRepository.getSources();
    return sources.firstWhere(
      (source) =>
          source.enabled && source.endpoint.contains('/fapigw/aibrief/list'),
      orElse: () => throw const AiBriefException(
        'Add and enable the Juhe AI brief list endpoint before refreshing hotspots.',
      ),
    );
  }

  Future<List<AiBriefArticle>> _filterWithAi(
    List<AiBriefArticle> candidates,
  ) async {
    if (candidates.isEmpty) {
      return const [];
    }

    final settings = await _aiSettingsRepository.getSettings();
    if (!settings.isConfigured) {
      return candidates;
    }

    try {
      final selected = await OpenAiCompatibleClient(settings)
          .selectTopArticles([
            for (final article in candidates)
              NewsArticle(
                sourceName: article.sourceName,
                title: article.title,
                summary: article.summary,
                url: article.id,
                publishedAt: article.publishedAt,
              ),
          ]);
      final selectedIds = selected.map((article) => article.url).toSet();
      if (selectedIds.isEmpty) {
        return candidates;
      }
      return [
        for (final article in candidates)
          if (selectedIds.contains(article.id)) article,
      ];
    } on AiModelException {
      // Keep the local, strict filter usable when the optional remote model is
      // unavailable. The next refresh can retry the single model request.
      return candidates;
    } on FormatException {
      // Keep the local, strict filter usable when the optional remote model is
      // unavailable. The next refresh can retry the single model request.
      return candidates;
    }
  }
}
