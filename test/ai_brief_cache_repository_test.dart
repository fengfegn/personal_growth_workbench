import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/hotspots/data/ai_brief_cache_repository.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/ai_brief_article.dart';
import 'package:personal_growth_workbench/features/settings/data/app_settings_repository.dart';

void main() {
  late AppDatabase database;
  late AiBriefCacheRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = AiBriefCacheRepository(AppSettingsRepository(database));
  });

  tearDown(() => database.close());

  test('reads same-day cached briefs without any remote dependency', () async {
    final now = DateTime(2026, 8, 12, 9);
    const article = AiBriefArticle(
      id: 'brief-1',
      title: 'Technology update',
      sourceName: 'Source',
      type: 'tech',
      imageUrl: '',
      summary: 'Summary',
      publishedAt: null,
      url: 'https://example.com',
    );

    await repository.saveCachedArticles([article], now: now);

    final cached = await repository.getCachedArticles(now: now);
    expect(cached, hasLength(1));
    expect(cached.single.id, article.id);
    expect(cached.single.title, article.title);
    expect(
      await repository.getCachedArticles(now: now.add(const Duration(days: 1))),
      isEmpty,
    );
  });

  test('limits requests locally and resets usage on the next date', () async {
    final today = DateTime(2026, 8, 12, 9);
    await repository.setMaxRequests(3, now: today);
    await repository.reserveRequests(3, now: today);

    final exhausted = await repository.getBudget(now: today);
    expect(exhausted.remainingRequests, 0);
    expect(
      () => repository.reserveRequests(1, now: today),
      throwsA(isA<AiBriefRequestLimitException>()),
    );

    final tomorrow = await repository.getBudget(
      now: today.add(const Duration(days: 1)),
    );
    expect(tomorrow.maxRequests, 3);
    expect(tomorrow.usedRequests, 0);
    expect(tomorrow.remainingRequests, 3);
  });

  test('stores fetched detail content in the existing daily cache', () async {
    final now = DateTime(2026, 8, 12, 9);
    const article = AiBriefArticle(
      id: 'brief-1',
      title: 'Technology update',
      sourceName: 'Source',
      type: 'tech',
      imageUrl: '',
      summary: 'Summary',
      publishedAt: null,
      url: 'https://example.com',
    );
    const detail = AiBriefArticle(
      id: 'brief-1',
      title: 'Technology update',
      sourceName: 'Source',
      type: 'tech',
      imageUrl: '',
      summary: 'Summary',
      publishedAt: null,
      url: 'https://example.com',
      content: 'Cached full text',
    );
    await repository.saveCachedArticles([article], now: now);

    await repository.updateCachedArticle(detail, now: now);

    expect(
      (await repository.getCachedArticles(now: now)).single.content,
      'Cached full text',
    );
  });
}
