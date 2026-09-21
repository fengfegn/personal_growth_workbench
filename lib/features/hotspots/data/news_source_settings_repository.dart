import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/news_source.dart';
import 'package:personal_growth_workbench/features/settings/data/app_settings_repository.dart';
import 'package:uuid/uuid.dart';

abstract interface class NewsSourceSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterNewsSourceSecretStore implements NewsSourceSecretStore {
  FlutterNewsSourceSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class NewsSourceSettingsRepository {
  NewsSourceSettingsRepository(
    AppDatabase database, {
    NewsSourceSecretStore? secretStore,
  }) : _appSettings = AppSettingsRepository(database),
       _secretStore = secretStore ?? FlutterNewsSourceSecretStore();

  static const _settingsKey = 'hotspot_news_sources';

  final AppSettingsRepository _appSettings;
  final NewsSourceSecretStore _secretStore;

  Future<List<NewsSourceConfig>> getSources() async {
    final json = await _appSettings.readJson(_settingsKey);
    final values = json?['sources'];
    if (values is! List) {
      return const [];
    }
    final ids = <String>{};
    final sources = <NewsSourceConfig>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final parsed = NewsSourceConfig.fromJson(value);
      if (parsed.name.isEmpty) {
        continue;
      }
      var id = parsed.id.isNotEmpty ? parsed.id : _legacyId(parsed, index);
      while (!ids.add(id)) {
        id = '$id-$index';
      }
      final apiKey = await _secretStore.read(_storageKey(id)) ?? '';
      sources.add(parsed.copyWith(id: id, apiKey: apiKey));
    }
    return sources;
  }

  Future<void> saveSources(List<NewsSourceConfig> sources) async {
    final previous = await getSources();
    final normalized = <NewsSourceConfig>[];
    final ids = <String>{};
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      var id = source.id.trim();
      if (id.isEmpty) {
        id = Uuid().v4();
      }
      while (!ids.add(id)) {
        id = '${Uuid().v4()}-$index';
      }
      normalized.add(
        source.copyWith(
          id: id,
          name: source.name.trim(),
          endpoint: source.endpoint.trim(),
          apiKey: source.apiKey.trim(),
        ),
      );
    }

    final currentIds = normalized.map((source) => source.id).toSet();
    for (final source in previous) {
      if (!currentIds.contains(source.id)) {
        await _secretStore.delete(_storageKey(source.id));
      }
    }
    for (final source in normalized) {
      if (source.apiKey.isEmpty) {
        await _secretStore.delete(_storageKey(source.id));
      } else {
        await _secretStore.write(_storageKey(source.id), source.apiKey);
      }
    }
    await _appSettings.writeJson(_settingsKey, {
      'sources': [for (final source in normalized) source.toJson()],
    });
  }

  String _storageKey(String id) => 'hotspot_news_source_api_key_$id';

  String _legacyId(NewsSourceConfig source, int index) {
    var hash = 17;
    for (final codeUnit in '${source.name}\u0000${source.endpoint}'.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return 'legacy-$hash-$index';
  }
}
