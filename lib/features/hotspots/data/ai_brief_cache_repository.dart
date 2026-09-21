import '../../../core/time/local_date.dart';
import '../../settings/data/app_settings_repository.dart';
import '../domain/ai_brief_article.dart';

class AiBriefRequestLimitException implements Exception {
  const AiBriefRequestLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiBriefRequestBudget {
  const AiBriefRequestBudget({
    required this.localDate,
    required this.maxRequests,
    required this.usedRequests,
  });

  final String localDate;
  final int maxRequests;
  final int usedRequests;

  int get remainingRequests => maxRequests - usedRequests;
}

class AiBriefCacheRepository {
  AiBriefCacheRepository(AppSettingsRepository settings) : _settings = settings;

  static const _cacheKey = 'ai_brief_daily_cache_v1';
  static const _budgetKey = 'ai_brief_request_budget_v1';
  static const _defaultMaxRequests = 10;

  final AppSettingsRepository _settings;

  Future<List<AiBriefArticle>> getCachedArticles({DateTime? now}) async {
    final localDate = localDateKey(now ?? DateTime.now());
    final json = await _settings.readJson(_cacheKey);
    if (json?['localDate'] != localDate) {
      return const [];
    }
    final values = json?['articles'];
    if (values is! List) {
      return const [];
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(AiBriefArticle.fromJson)
        .where((article) => article.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveCachedArticles(
    List<AiBriefArticle> articles, {
    DateTime? now,
  }) {
    return _settings.writeJson(_cacheKey, {
      'localDate': localDateKey(now ?? DateTime.now()),
      'articles': [for (final article in articles) article.toJson()],
    });
  }

  Future<void> updateCachedArticle(
    AiBriefArticle article, {
    DateTime? now,
  }) async {
    final cached = await getCachedArticles(now: now);
    await saveCachedArticles([
      for (final item in cached)
        if (item.id == article.id) article else item,
    ], now: now);
  }

  Future<AiBriefRequestBudget> getBudget({DateTime? now}) async {
    final date = localDateKey(now ?? DateTime.now());
    final json = await _settings.readJson(_budgetKey);
    final maxRequests = _positive(json?['maxRequests'], _defaultMaxRequests);
    final usedRequests = json?['localDate'] == date
        ? _nonNegative(json?['usedRequests'])
        : 0;
    return AiBriefRequestBudget(
      localDate: date,
      maxRequests: maxRequests,
      usedRequests: usedRequests,
    );
  }

  Future<void> setMaxRequests(int maxRequests, {DateTime? now}) async {
    final budget = await getBudget(now: now);
    await _writeBudget(
      AiBriefRequestBudget(
        localDate: budget.localDate,
        maxRequests: maxRequests.clamp(1, 100),
        usedRequests: budget.usedRequests,
      ),
    );
  }

  Future<void> reserveRequests(int count, {DateTime? now}) async {
    final budget = await getBudget(now: now);
    if (count <= 0) {
      return;
    }
    if (budget.remainingRequests < count) {
      throw AiBriefRequestLimitException(
        'Daily request limit reached: ${budget.usedRequests}/${budget.maxRequests} used. '
        'Increase the limit in Settings or try again tomorrow.',
      );
    }
    await _writeBudget(
      AiBriefRequestBudget(
        localDate: budget.localDate,
        maxRequests: budget.maxRequests,
        usedRequests: budget.usedRequests + count,
      ),
    );
  }

  Future<void> _writeBudget(AiBriefRequestBudget budget) {
    return _settings.writeJson(_budgetKey, {
      'localDate': budget.localDate,
      'maxRequests': budget.maxRequests,
      'usedRequests': budget.usedRequests,
    });
  }

  int _positive(dynamic value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  int _nonNegative(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed >= 0 ? parsed : 0;
  }
}
