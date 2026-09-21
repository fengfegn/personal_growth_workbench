import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

class UserProfileRepository {
  UserProfileRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<UserProfile> getOrCreate() async {
    final existing = await (_database.select(
      _database.userProfiles,
    )..limit(1)).getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: id,
            nickname: '你的昵称',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await (_database.select(
      _database.userProfiles,
    )..where((profile) => profile.id.equals(id))).getSingle());
  }

  Future<UserProfile> updateNickname(String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('昵称不能为空');
    }

    final profile = await getOrCreate();
    await (_database.update(
      _database.userProfiles,
    )..where((row) => row.id.equals(profile.id))).write(
      UserProfilesCompanion(
        nickname: Value(normalized),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return (await (_database.select(
      _database.userProfiles,
    )..where((row) => row.id.equals(profile.id))).getSingle());
  }
}
