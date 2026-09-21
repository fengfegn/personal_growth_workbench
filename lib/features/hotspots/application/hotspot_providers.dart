import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/time/local_date.dart';
import '../../ai/data/ai_settings_repository.dart';
import '../../ai/domain/ai_provider.dart';
import '../../settings/data/app_settings_repository.dart';
import '../data/ai_brief_cache_repository.dart';
import '../data/hotspot_repository.dart';
import '../data/ai_brief_repository.dart';
import '../data/news_source_settings_repository.dart';
import '../domain/hotspot.dart';
import '../domain/ai_brief_article.dart';
import '../domain/news_source.dart';
import 'hotspot_generator.dart';
import 'hotspot_pipeline_diagnostics.dart';

final hotspotRepositoryProvider = Provider<HotspotRepository>((ref) {
  return HotspotRepository(ref.watch(appDatabaseProvider));
});

final aiBriefCacheRepositoryProvider = Provider<AiBriefCacheRepository>((ref) {
  return AiBriefCacheRepository(
    AppSettingsRepository(ref.watch(appDatabaseProvider)),
  );
});

final aiBriefRepositoryProvider = Provider<AiBriefRepository>((ref) {
  return AiBriefRepository(
    ref.watch(newsSourceSettingsRepositoryProvider),
    aiSettingsRepository: ref.watch(aiSettingsRepositoryProvider),
    cacheRepository: ref.watch(aiBriefCacheRepositoryProvider),
  );
});

final aiBriefArticlesProvider = FutureProvider<List<AiBriefArticle>>((ref) {
  return ref.watch(aiBriefRepositoryProvider).getCachedArticles();
});

final aiBriefRequestBudgetProvider = FutureProvider<AiBriefRequestBudget>((
  ref,
) {
  return ref.watch(aiBriefCacheRepositoryProvider).getBudget();
});

final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  return AiSettingsRepository(ref.watch(appDatabaseProvider));
});

final aiSettingsProvider = FutureProvider<AiProviderSettings>((ref) {
  return ref.watch(aiSettingsRepositoryProvider).getSettings();
});

final newsSourceSettingsRepositoryProvider =
    Provider<NewsSourceSettingsRepository>((ref) {
      return NewsSourceSettingsRepository(ref.watch(appDatabaseProvider));
    });

final newsSourceSettingsProvider = FutureProvider<List<NewsSourceConfig>>((
  ref,
) {
  return ref.watch(newsSourceSettingsRepositoryProvider).getSources();
});

final todayHotspotsProvider = FutureProvider<List<HotspotDigest>>((ref) {
  return ref
      .watch(hotspotRepositoryProvider)
      .getForDate(localDateKey(DateTime.now()));
});

final hotspotGeneratorProvider = Provider<HotspotGenerator>((ref) {
  return HotspotGenerator(
    hotspotRepository: ref.watch(hotspotRepositoryProvider),
    aiSettingsRepository: ref.watch(aiSettingsRepositoryProvider),
    newsSourceSettingsRepository: ref.watch(
      newsSourceSettingsRepositoryProvider,
    ),
  );
});

final hotspotPipelineDiagnosticsProvider = Provider<HotspotPipelineDiagnostics>(
  (ref) {
    return HotspotPipelineDiagnostics(
      aiSettingsRepository: ref.watch(aiSettingsRepositoryProvider),
      newsSourceSettingsRepository: ref.watch(
        newsSourceSettingsRepositoryProvider,
      ),
    );
  },
);

void invalidateHotspotData(WidgetRef ref) {
  ref.invalidate(aiSettingsProvider);
  ref.invalidate(newsSourceSettingsProvider);
  ref.invalidate(todayHotspotsProvider);
  ref.invalidate(aiBriefArticlesProvider);
  ref.invalidate(aiBriefRequestBudgetProvider);
}
