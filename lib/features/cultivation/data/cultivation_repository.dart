import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart'
    hide
        AdvancementExam,
        AdvancementHistory,
        CultivationProfile,
        CultivationSession,
        RealmAdvancementHistory,
        RealmTrial,
        Technique;
import '../domain/cultivation.dart';
import '../domain/cultivation_settlement.dart';
import '../domain/realm.dart';

class CultivationRepository {
  CultivationRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();
  static const _profileId = 'default-cultivation-profile';

  Future<CultivationProfile> getOrCreateProfile() async {
    final existing = await (_database.select(
      _database.cultivationProfiles,
    )..where((profile) => profile.id.equals(_profileId))).getSingleOrNull();
    if (existing != null) return CultivationProfile.fromRow(existing);
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.cultivationProfiles)
        .insert(
          CultivationProfilesCompanion.insert(
            id: _profileId,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getProfile();
  }

  Future<CultivationProfile> getProfile() async {
    final row = await (_database.select(
      _database.cultivationProfiles,
    )..where((profile) => profile.id.equals(_profileId))).getSingle();
    return CultivationProfile.fromRow(row);
  }

  Future<List<Technique>> getTechniques({bool includeArchived = false}) async {
    final query = _database.select(_database.techniques)
      ..where((technique) {
        final active = technique.deletedAt.isNull();
        return includeArchived
            ? active
            : active & technique.status.equals('active');
      })
      ..orderBy([
        (technique) => OrderingTerm(
          expression: technique.updatedAt,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();
    return rows.map(Technique.fromRow).toList(growable: false);
  }

  Future<Technique> getTechnique(String id) async {
    final row = await (_database.select(
      _database.techniques,
    )..where((technique) => technique.id.equals(id))).getSingle();
    return Technique.fromRow(row);
  }

  Future<Technique> createTechnique({
    required String name,
    String? description,
    String? category,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('功法名称不能为空');
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.techniques)
        .insert(
          TechniquesCompanion.insert(
            id: id,
            name: normalizedName,
            description: Value(_nullableText(description)),
            category: Value(_nullableText(category)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getTechnique(id);
  }

  Future<Technique> updateTechnique({
    required String id,
    required String name,
    String? description,
    String? category,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('功法名称不能为空');
    await (_database.update(
      _database.techniques,
    )..where((technique) => technique.id.equals(id))).write(
      TechniquesCompanion(
        name: Value(normalizedName),
        description: Value(_nullableText(description)),
        category: Value(_nullableText(category)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    return getTechnique(id);
  }

  Future<void> archiveTechnique(String id) async {
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.techniques,
    )..where((technique) => technique.id.equals(id))).write(
      TechniquesCompanion(
        status: const Value('archived'),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<CultivationSession>> getRecentSessions({
    String? techniqueId,
    int limit = 10,
  }) async {
    final query = _database.select(_database.cultivationSessions)
      ..orderBy([
        (session) =>
            OrderingTerm(expression: session.endedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (techniqueId != null) {
      query.where((session) => session.techniqueId.equals(techniqueId));
    }
    final rows = await query.get();
    return rows.map(CultivationSession.fromRow).toList(growable: false);
  }

  Future<List<AdvancementExam>> getActiveExams() async {
    final query = _database.select(_database.advancementExams)
      ..where(
        (exam) => exam.status.isIn([
          ExamStatus.notStarted.storage,
          ExamStatus.inProgress.storage,
          ExamStatus.pendingReview.storage,
        ]),
      )
      ..orderBy([(exam) => OrderingTerm(expression: exam.createdAt)]);
    final rows = await query.get();
    return rows.map(AdvancementExam.fromRow).toList(growable: false);
  }

  Future<AdvancementExam?> getActiveExam(String techniqueId) async {
    final row =
        await (_database.select(_database.advancementExams)
              ..where(
                (exam) =>
                    exam.techniqueId.equals(techniqueId) &
                    exam.status.isIn([
                      ExamStatus.notStarted.storage,
                      ExamStatus.inProgress.storage,
                      ExamStatus.pendingReview.storage,
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : AdvancementExam.fromRow(row);
  }

  Future<List<AdvancementHistory>> getAdvancementHistory(
    String techniqueId,
  ) async {
    final query = _database.select(_database.advancementHistories)
      ..where((item) => item.techniqueId.equals(techniqueId))
      ..orderBy([
        (item) =>
            OrderingTerm(expression: item.advancedAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(AdvancementHistory.fromRow).toList(growable: false);
  }

  Future<RealmTrial?> getActiveRealmTrial() async {
    final row =
        await (_database.select(_database.realmTrials)
              ..where(
                (trial) => trial.status.isIn([
                  RealmTrialStatus.notStarted.storage,
                  RealmTrialStatus.inProgress.storage,
                  RealmTrialStatus.pendingReview.storage,
                ]),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : RealmTrial.fromRow(row);
  }

  Future<RealmTrial?> getRealmTrial(String id) async {
    final row = await (_database.select(
      _database.realmTrials,
    )..where((trial) => trial.id.equals(id))).getSingleOrNull();
    return row == null ? null : RealmTrial.fromRow(row);
  }

  Future<List<RealmAdvancementHistory>> getRealmAdvancementHistory() async {
    final query = _database.select(_database.realmAdvancementHistories)
      ..orderBy([
        (item) =>
            OrderingTerm(expression: item.advancedAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(RealmAdvancementHistory.fromRow).toList(growable: false);
  }

  Future<RealmTrial> createRealmTrial({
    required String title,
    required String objective,
    required String acceptanceCriteria,
    String? note,
  }) async {
    final profile = await getOrCreateProfile();
    final next = getNextRealm(profile.currentRealm);
    if (next == null) throw StateError('当前已是最高境界');
    final progress = calculateRealmProgress(
      currentRealm: profile.currentRealm,
      mentalPoints: profile.mentalPoints,
      physicalPoints: profile.physicalPoints,
      mentalProgressSeconds: profile.mentalProgressSeconds,
      physicalProgressSeconds: profile.physicalProgressSeconds,
    );
    if (!progress.ready) throw StateError('精神和体质尚未同时满足突破要求');
    if (await getActiveRealmTrial() != null) {
      throw StateError('当前已有进行中的境界试炼');
    }
    final normalizedTitle = title.trim();
    final normalizedObjective = objective.trim();
    final normalizedCriteria = acceptanceCriteria.trim();
    if (normalizedTitle.isEmpty ||
        normalizedObjective.isEmpty ||
        normalizedCriteria.isEmpty) {
      throw ArgumentError('试炼名称、目标和验收标准不能为空');
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.realmTrials)
        .insert(
          RealmTrialsCompanion.insert(
            id: id,
            fromRealm: profile.currentRealm,
            toRealm: next.index,
            title: normalizedTitle,
            objective: normalizedObjective,
            acceptanceCriteria: normalizedCriteria,
            note: Value(_nullableText(note)),
            createdAt: now,
          ),
        );
    return (await getRealmTrial(id))!;
  }

  Future<RealmTrial> setRealmTrialStatus(
    String id,
    RealmTrialStatus status,
  ) async {
    final trial = await getRealmTrial(id);
    if (trial == null) throw StateError('境界试炼不存在');
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.realmTrials,
    )..where((item) => item.id.equals(id))).write(
      RealmTrialsCompanion(
        status: Value(status.storage),
        startedAt: status == RealmTrialStatus.inProgress
            ? Value(trial.startedAt ?? now)
            : const Value.absent(),
        submittedAt: status == RealmTrialStatus.pendingReview
            ? Value(now)
            : const Value.absent(),
      ),
    );
    return (await getRealmTrial(id))!;
  }

  Future<void> passRealmTrial(String id) async {
    await _database.transaction(() async {
      final trial = await getRealmTrial(id);
      if (trial == null || trial.status != RealmTrialStatus.pendingReview) {
        throw StateError('只有待验收的境界试炼才能通过');
      }
      final profile = await getOrCreateProfile();
      final next = getNextRealm(profile.currentRealm);
      final progress = calculateRealmProgress(
        currentRealm: profile.currentRealm,
        mentalPoints: profile.mentalPoints,
        physicalPoints: profile.physicalPoints,
        mentalProgressSeconds: profile.mentalProgressSeconds,
        physicalProgressSeconds: profile.physicalProgressSeconds,
      );
      final existingHistory = await (_database.select(
        _database.realmAdvancementHistories,
      )..where((item) => item.trialId.equals(id))).getSingleOrNull();
      if (next == null ||
          existingHistory != null ||
          trial.fromRealm != profile.currentRealm ||
          trial.toRealm != next.index ||
          !progress.ready) {
        throw StateError('当前境界状态已发生变化，无法突破');
      }
      final now = DateTime.now().toUtc();
      await (_database.update(
        _database.realmTrials,
      )..where((item) => item.id.equals(id))).write(
        RealmTrialsCompanion(
          status: const Value('passed'),
          reviewedAt: Value(now),
          completedAt: Value(now),
        ),
      );
      await (_database.update(
        _database.cultivationProfiles,
      )..where((item) => item.id.equals(profile.id))).write(
        CultivationProfilesCompanion(
          currentRealm: Value(next.index),
          updatedAt: Value(now),
        ),
      );
      await _database
          .into(_database.realmAdvancementHistories)
          .insert(
            RealmAdvancementHistoriesCompanion.insert(
              id: _uuid.v4(),
              fromRealm: profile.currentRealm,
              toRealm: next.index,
              trialId: id,
              mentalAtBreakthrough: profile.mentalPoints,
              physicalAtBreakthrough: profile.physicalPoints,
              advancedAt: now,
            ),
          );
    });
  }

  Future<void> failRealmTrial(String id) async {
    final trial = await getRealmTrial(id);
    if (trial == null || trial.status != RealmTrialStatus.pendingReview) {
      throw StateError('只有待验收的境界试炼才能标记未通过');
    }
    await (_database.update(
      _database.realmTrials,
    )..where((item) => item.id.equals(id))).write(
      RealmTrialsCompanion(
        status: const Value('failed'),
        reviewedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<CultivationSession> finishSession({
    String? id,
    required CultivationType type,
    String? techniqueId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    String? note,
  }) async {
    final sessionId = id ?? _uuid.v4();
    final safeDurationSeconds = durationSeconds < 0 ? 0 : durationSeconds;
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.cultivationSessions,
      )..where((session) => session.id.equals(sessionId))).getSingleOrNull();
      if (existing != null) return;

      final profile = await getOrCreateProfile();
      Technique? technique;
      if (techniqueId != null) technique = await getTechnique(techniqueId);
      final result = settleCultivationSession(
        type: type,
        durationSeconds: durationSeconds,
        mentalProgressSeconds: profile.mentalProgressSeconds,
        physicalProgressSeconds: profile.physicalProgressSeconds,
        proficiency: technique?.proficiency ?? 0,
        proficiencyProgressSeconds: technique?.proficiencyProgressSeconds ?? 0,
        techniqueId: techniqueId,
      );
      final now = DateTime.now().toUtc();
      await _database
          .into(_database.cultivationSessions)
          .insert(
            CultivationSessionsCompanion.insert(
              id: sessionId,
              type: type.storage,
              techniqueId: Value(techniqueId),
              startedAt: startedAt.toUtc(),
              endedAt: endedAt.toUtc(),
              durationSeconds: Value(safeDurationSeconds),
              mentalGained: Value(result.mentalPoints),
              physicalGained: Value(result.physicalPoints),
              proficiencyGained: Value(
                result.proficiency - (technique?.proficiency ?? 0),
              ),
              note: Value(_nullableText(note)),
              settled: const Value(true),
              createdAt: now,
            ),
          );
      await (_database.update(
        _database.cultivationProfiles,
      )..where((item) => item.id.equals(_profileId))).write(
        CultivationProfilesCompanion(
          mentalPoints: Value(profile.mentalPoints + result.mentalPoints),
          physicalPoints: Value(profile.physicalPoints + result.physicalPoints),
          mentalProgressSeconds: Value(result.mentalProgressSeconds),
          physicalProgressSeconds: Value(result.physicalProgressSeconds),
          updatedAt: Value(now),
        ),
      );
      if (technique != null) {
        await (_database.update(
          _database.techniques,
        )..where((item) => item.id.equals(technique!.id))).write(
          TechniquesCompanion(
            proficiency: Value(result.proficiency),
            proficiencyProgressSeconds: Value(
              result.proficiencyProgressSeconds,
            ),
            totalSeconds: Value(technique.totalSeconds + safeDurationSeconds),
            updatedAt: Value(now),
          ),
        );
      }
    });
    return getSession(sessionId);
  }

  Future<CultivationSession> getSession(String id) async {
    final row = await (_database.select(
      _database.cultivationSessions,
    )..where((session) => session.id.equals(id))).getSingle();
    return CultivationSession.fromRow(row);
  }

  Future<AdvancementExam> createExam({
    required String techniqueId,
    required String title,
    required String objective,
    required String acceptanceCriteria,
    String? note,
  }) async {
    final technique = await getTechnique(techniqueId);
    if (!technique.canAdvance()) throw StateError('当前还不满足进阶条件');
    if (await getActiveExam(techniqueId) != null) {
      throw StateError('同一功法只能有一个进行中的考核');
    }
    final normalizedTitle = title.trim();
    final normalizedObjective = objective.trim();
    final normalizedCriteria = acceptanceCriteria.trim();
    if (normalizedTitle.isEmpty ||
        normalizedObjective.isEmpty ||
        normalizedCriteria.isEmpty) {
      throw ArgumentError('考核名称、目标和验收标准不能为空');
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.advancementExams)
        .insert(
          AdvancementExamsCompanion.insert(
            id: id,
            techniqueId: techniqueId,
            fromLevel: technique.level,
            toLevel: technique.nextStage!.level,
            title: normalizedTitle,
            objective: normalizedObjective,
            acceptanceCriteria: normalizedCriteria,
            note: Value(_nullableText(note)),
            createdAt: now,
          ),
        );
    return getExam(id);
  }

  Future<AdvancementExam> getExam(String id) async {
    final row = await (_database.select(
      _database.advancementExams,
    )..where((exam) => exam.id.equals(id))).getSingle();
    return AdvancementExam.fromRow(row);
  }

  Future<AdvancementExam> setExamStatus(String id, ExamStatus status) async {
    final exam = await getExam(id);
    final now = DateTime.now().toUtc();
    final submittedAt = status == ExamStatus.pendingReview
        ? Value(now)
        : const Value<DateTime?>(null);
    await (_database.update(
      _database.advancementExams,
    )..where((item) => item.id.equals(id))).write(
      AdvancementExamsCompanion(
        status: Value(status.storage),
        submittedAt: submittedAt,
      ),
    );
    return getExam(exam.id);
  }

  Future<void> passExam(String id) async {
    await _database.transaction(() async {
      final exam = await getExam(id);
      if (exam.status != ExamStatus.pendingReview) {
        throw StateError('只有待验收的考核才能通过');
      }
      final technique = await getTechnique(exam.techniqueId);
      final next = technique.nextStage;
      if (next == null ||
          technique.level != exam.fromLevel ||
          next.level != exam.toLevel ||
          technique.proficiency < next.requiredProficiency) {
        throw StateError('当前功法状态已发生变化，无法晋升');
      }
      final now = DateTime.now().toUtc();
      await (_database.update(
        _database.advancementExams,
      )..where((item) => item.id.equals(id))).write(
        AdvancementExamsCompanion(
          status: const Value('passed'),
          reviewedAt: Value(now),
        ),
      );
      await (_database.update(
        _database.techniques,
      )..where((item) => item.id.equals(technique.id))).write(
        TechniquesCompanion(level: Value(next.level), updatedAt: Value(now)),
      );
      await _database
          .into(_database.advancementHistories)
          .insert(
            AdvancementHistoriesCompanion.insert(
              id: _uuid.v4(),
              techniqueId: technique.id,
              fromLevel: technique.level,
              toLevel: next.level,
              examId: id,
              advancedAt: now,
            ),
          );
    });
  }

  Future<void> failExam(String id) async {
    final exam = await getExam(id);
    if (exam.status != ExamStatus.pendingReview) {
      throw StateError('只有待验收的考核才能标记未通过');
    }
    await (_database.update(
      _database.advancementExams,
    )..where((item) => item.id.equals(id))).write(
      AdvancementExamsCompanion(
        status: const Value('failed'),
        reviewedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
