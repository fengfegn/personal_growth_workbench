import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/hotspots/data/news_source_client.dart';
import 'package:personal_growth_workbench/features/hotspots/data/news_source_settings_repository.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/news_source.dart';

class _MemorySecretStore implements NewsSourceSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test(
    'returns no fixed sources when the list has not been configured',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      final repository = NewsSourceSettingsRepository(
        database,
        secretStore: _MemorySecretStore(),
      );

      expect(await repository.getSources(), isEmpty);
    },
  );

  test(
    'persists editable source fields and keeps API keys out of app settings',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final secrets = _MemorySecretStore();
      final repository = NewsSourceSettingsRepository(
        database,
        secretStore: secrets,
      );

      await repository.saveSources([
        const NewsSourceConfig(
          id: 'source-1',
          name: '政策源',
          endpoint: 'https://example.com/policy',
          apiKey: 'secret-value',
          responseType: NewsResponseType.rss,
        ),
      ]);

      final loaded = (await repository.getSources()).single;
      expect(loaded.name, '政策源');
      expect(loaded.endpoint, 'https://example.com/policy');
      expect(loaded.apiKey, 'secret-value');
      expect(loaded.responseType, NewsResponseType.rss);
      expect(secrets.values.values, contains('secret-value'));

      final row =
          await (database.select(
                database.appSettings,
              )..where((setting) => setting.key.equals('hotspot_news_sources')))
              .getSingle();
      expect(row.valueJson, isNot(contains('secret-value')));
      expect(
        jsonDecode(row.valueJson)['sources'].single['responseType'],
        'rss',
      );

      await repository.saveSources([]);
      expect(await repository.getSources(), isEmpty);
      expect(secrets.values, isEmpty);
    },
  );

  test('defaults legacy sources without response type to JSON', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final secrets = _MemorySecretStore();
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'hotspot_news_sources',
            valueJson: jsonEncode({
              'sources': [
                {'name': '旧来源', 'endpoint': 'https://example.com'},
              ],
            }),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    final source = (await NewsSourceSettingsRepository(
      database,
      secretStore: secrets,
    ).getSources()).single;
    expect(source.id, startsWith('legacy-'));
    expect(source.responseType, NewsResponseType.json);
  });

  test('parses result newslist and sends page, num, and API key', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      expect(request.uri.queryParameters['page'], '2');
      expect(request.uri.queryParameters['num'], '20');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer source-secret',
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'reason': 'success',
          'result': {
            'curpage': 2,
            'newslist': [
              {
                'title': 'A headline',
                'description': 'A short description',
                'source': 'Test source',
                'ctime': '2026-08-07 21:07:34',
                'url': 'https://example.com/article',
              },
            ],
          },
        }),
      );
      request.response.close();
    });

    final articles = await NewsSourceClient().fetch(
      NewsSourceConfig(
        name: 'Test API',
        endpoint: 'http://${server.address.host}:${server.port}',
        apiKey: 'source-secret',
        page: 2,
        pageSize: 20,
      ),
    );

    expect(articles.single.title, 'A headline');
    expect(articles.single.sourceName, 'Test source');
    expect(articles.single.publishedAt, DateTime(2026, 8, 7, 21, 7, 34));
  });

  test('sends a configured API key as a query parameter', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      expect(request.uri.queryParameters['key'], 'source-secret');
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode([
          {'title': 'A headline', 'url': 'https://example.com/article'},
        ]),
      );
      request.response.close();
    });

    final articles = await NewsSourceClient().fetch(
      NewsSourceConfig(
        name: 'Query key API',
        endpoint: 'http://${server.address.host}:${server.port}',
        apiKey: 'source-secret',
        apiKeyLocation: NewsApiKeyLocation.query,
      ),
    );

    expect(articles.single.title, 'A headline');
  });
}
