import 'dart:convert';

import '../../../core/database/app_database.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._database);

  final AppDatabase _database;

  Future<Map<String, dynamic>?> readJson(String key) async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final decoded = jsonDecode(row.valueJson);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            valueJson: jsonEncode(value),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
