import '../../ai/data/ai_settings_repository.dart';
import '../data/ai_model_client.dart';
import '../data/news_source_client.dart';
import '../data/news_source_settings_repository.dart';
import '../domain/news_source.dart';
import 'hotspot_article_filter.dart';

class HotspotPipelineDiagnostics {
  HotspotPipelineDiagnostics({
    required this.aiSettingsRepository,
    required this.newsSourceSettingsRepository,
    NewsSourceClient? newsSourceClient,
  }) : newsSourceClient = newsSourceClient ?? NewsSourceClient();

  final AiSettingsRepository aiSettingsRepository;
  final NewsSourceSettingsRepository newsSourceSettingsRepository;
  final NewsSourceClient newsSourceClient;

  Future<HotspotDiagnosticResult> verify() async {
    final settings = await aiSettingsRepository.getSettings();
    final sources = await newsSourceSettingsRepository.getSources();
    final enabledSources = sources
        .where((source) => source.enabled && source.endpoint.trim().isNotEmpty)
        .toList(growable: false);
    final sourceResults = <HotspotSourceDiagnostic>[];
    final articles = <NewsArticle>[];

    for (final source in enabledSources) {
      try {
        final fetched = await newsSourceClient.fetch(source);
        articles.addAll(fetched);
        sourceResults.add(
          HotspotSourceDiagnostic(
            name: source.name,
            articleCount: fetched.length,
          ),
        );
      } on NewsSourceException catch (error) {
        sourceResults.add(
          HotspotSourceDiagnostic(name: source.name, error: error.message),
        );
      }
    }

    String? aiError;
    if (settings.isConfigured) {
      try {
        await OpenAiCompatibleClient(settings).verifyConnection();
      } on AiModelException catch (error) {
        aiError = error.message;
      }
    } else {
      aiError =
          'AI is disabled or its API key is unavailable in secure storage.';
    }

    return HotspotDiagnosticResult(
      aiConfigured: settings.isConfigured,
      aiError: aiError,
      enabledSourceCount: enabledSources.length,
      sourceResults: sourceResults,
      fetchedArticleCount: articles.length,
      relevantArticleCount: HotspotArticleFilter.keepRelevant(articles).length,
    );
  }
}

class HotspotDiagnosticResult {
  const HotspotDiagnosticResult({
    required this.aiConfigured,
    required this.aiError,
    required this.enabledSourceCount,
    required this.sourceResults,
    required this.fetchedArticleCount,
    required this.relevantArticleCount,
  });

  final bool aiConfigured;
  final String? aiError;
  final int enabledSourceCount;
  final List<HotspotSourceDiagnostic> sourceResults;
  final int fetchedArticleCount;
  final int relevantArticleCount;

  String get summary {
    final sourceStatus = sourceResults
        .map(
          (result) => result.error == null
              ? '${result.name}: ${result.articleCount} JSON articles'
              : '${result.name}: ${result.error}',
        )
        .join('\n');
    final modelStatus = aiError == null
        ? 'Model: reachable'
        : 'Model: $aiError';
    return '$modelStatus\nEnabled sources: $enabledSourceCount\n'
        'Fetched: $fetchedArticleCount; relevant after local filtering: '
        '$relevantArticleCount\n$sourceStatus';
  }
}

class HotspotSourceDiagnostic {
  const HotspotSourceDiagnostic({
    required this.name,
    this.articleCount = 0,
    this.error,
  });

  final String name;
  final int articleCount;
  final String? error;
}
