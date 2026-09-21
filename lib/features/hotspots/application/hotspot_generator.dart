import '../../../core/time/local_date.dart';
import '../../ai/data/ai_settings_repository.dart';
import '../../hotspots/data/ai_model_client.dart';
import '../../hotspots/data/article_content_fetcher.dart';
import '../../hotspots/data/hotspot_repository.dart';
import '../../hotspots/data/news_source_client.dart';
import '../../hotspots/data/news_source_settings_repository.dart';
import '../domain/hotspot.dart';
import '../domain/news_source.dart';
import 'hotspot_article_filter.dart';

class HotspotGenerator {
  HotspotGenerator({
    required this.hotspotRepository,
    required this.aiSettingsRepository,
    required this.newsSourceSettingsRepository,
    NewsSourceClient? newsSourceClient,
    ArticleContentFetcher? articleContentFetcher,
  }) : newsSourceClient = newsSourceClient ?? NewsSourceClient(),
       articleContentFetcher =
           articleContentFetcher ?? PythonArticleContentFetcher();

  final HotspotRepository hotspotRepository;
  final AiSettingsRepository aiSettingsRepository;
  final NewsSourceSettingsRepository newsSourceSettingsRepository;
  final NewsSourceClient newsSourceClient;
  final ArticleContentFetcher articleContentFetcher;

  Future<List<HotspotDigest>> refresh({DateTime? now}) async {
    final settings = await aiSettingsRepository.getSettings();
    if (!settings.isConfigured) {
      throw const HotspotGenerationException('请先在设置中配置并启用大模型 API');
    }

    final sourceConfigs = await newsSourceSettingsRepository.getSources();
    final enabledSources = sourceConfigs.where(
      (source) => source.enabled && source.endpoint.trim().isNotEmpty,
    );
    final articles = <NewsArticle>[];
    final errors = <String>[];
    for (final source in enabledSources) {
      try {
        articles.addAll(await newsSourceClient.fetch(source));
      } on NewsSourceException catch (error) {
        errors.add(error.message);
      }
    }
    if (articles.isEmpty) {
      final detail = errors.isEmpty ? '' : '：${errors.join('；')}';
      throw HotspotGenerationException('没有获取到可用信息源$detail');
    }

    final relevantArticles = HotspotArticleFilter.keepRelevant(articles);
    if (relevantArticles.isEmpty) {
      throw const HotspotGenerationException(
        'No technology, finance, or world-affairs articles remained after local entertainment filtering.',
      );
    }

    final aiClient = OpenAiCompatibleClient(settings);
    final selected = await aiClient.selectTopArticles(relevantArticles);
    if (selected.isEmpty) {
      throw const HotspotGenerationException('大模型没有筛选出今日重点新闻');
    }
    final enriched = await articleContentFetcher.enrich(selected);
    final drafts = await aiClient.summarize(enriched);
    if (drafts.isEmpty) {
      throw const HotspotGenerationException('没有生成通过交叉验证的热点');
    }
    final date = localDateKey(now ?? DateTime.now());
    await hotspotRepository.replaceForDate(
      localDate: date,
      drafts: drafts,
      provider: settings.config.provider.label,
      model: settings.config.model,
    );
    return hotspotRepository.getForDate(date);
  }
}

class HotspotGenerationException implements Exception {
  const HotspotGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
