import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../settings/data/app_settings_repository.dart';
import '../domain/ai_provider.dart';

class AiSettingsRepository {
  AiSettingsRepository(
    AppDatabase database, {
    FlutterSecureStorage? secureStorage,
  }) : _appSettings = AppSettingsRepository(database),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _configKey = 'ai_provider_config';
  static const _apiKeyStorageKey = 'ai_provider_api_key';

  final AppSettingsRepository _appSettings;
  final FlutterSecureStorage _secureStorage;

  Future<AiProviderSettings> getSettings() async {
    final json = await _appSettings.readJson(_configKey);
    final config = json == null
        ? AiProviderConfig.defaults()
        : AiProviderConfig.fromJson(json);
    final apiKey = await _secureStorage.read(key: _apiKeyStorageKey) ?? '';
    return AiProviderSettings(config: config, apiKey: apiKey);
  }

  Future<void> saveSettings(AiProviderSettings settings) async {
    await _appSettings.writeJson(_configKey, settings.config.toJson());
    if (settings.apiKey.trim().isEmpty) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } else {
      await _secureStorage.write(
        key: _apiKeyStorageKey,
        value: settings.apiKey.trim(),
      );
    }
  }
}
