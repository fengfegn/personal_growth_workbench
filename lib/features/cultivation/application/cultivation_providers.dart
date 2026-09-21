import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/cultivation_repository.dart';
import '../domain/cultivation.dart';
import '../domain/realm.dart';
import '../domain/realm.dart' as realm_rules;

final cultivationRepositoryProvider = Provider<CultivationRepository>((ref) {
  return CultivationRepository(ref.watch(appDatabaseProvider));
});

final cultivationDashboardProvider = FutureProvider<CultivationDashboardData>((
  ref,
) async {
  final repository = ref.watch(cultivationRepositoryProvider);
  return CultivationDashboardData(
    profile: await repository.getOrCreateProfile(),
    techniques: await repository.getTechniques(),
    activeExams: await repository.getActiveExams(),
    activeRealmTrial: await repository.getActiveRealmTrial(),
    realmHistory: await repository.getRealmAdvancementHistory(),
    recentSessions: await repository.getRecentSessions(limit: 1000),
  );
});

final techniqueDetailProvider = FutureProvider.family<Technique, String>(
  (ref, id) => ref.watch(cultivationRepositoryProvider).getTechnique(id),
);

final techniqueSessionsProvider =
    FutureProvider.family<List<CultivationSession>, String>(
      (ref, id) => ref
          .watch(cultivationRepositoryProvider)
          .getRecentSessions(techniqueId: id, limit: 50),
    );

final techniqueHistoryProvider =
    FutureProvider.family<List<AdvancementHistory>, String>(
      (ref, id) =>
          ref.watch(cultivationRepositoryProvider).getAdvancementHistory(id),
    );

class CultivationDashboardData {
  const CultivationDashboardData({
    required this.profile,
    required this.techniques,
    required this.activeExams,
    required this.activeRealmTrial,
    required this.realmHistory,
    required this.recentSessions,
  });

  final CultivationProfile profile;
  final List<Technique> techniques;
  final List<AdvancementExam> activeExams;
  final RealmTrial? activeRealmTrial;
  final List<RealmAdvancementHistory> realmHistory;
  final List<CultivationSession> recentSessions;

  UserRealm get currentRealm => realmForIndex(profile.currentRealm);

  RealmProgress get realmProgress => calculateRealmProgress(
    currentRealm: profile.currentRealm,
    mentalPoints: profile.mentalPoints,
    physicalPoints: profile.physicalPoints,
    mentalProgressSeconds: profile.mentalProgressSeconds,
    physicalProgressSeconds: profile.physicalProgressSeconds,
  );

  bool get canAttemptRealmBreakthrough => canAttemptRealmBreakthroughRule;

  bool get canAttemptRealmBreakthroughRule =>
      realm_rules.canAttemptRealmBreakthrough(
        currentRealm: profile.currentRealm,
        mentalPoints: profile.mentalPoints,
        physicalPoints: profile.physicalPoints,
        hasActiveTrial: activeRealmTrial != null,
      );

  AdvancementExam? examFor(String techniqueId) {
    for (final exam in activeExams) {
      if (exam.techniqueId == techniqueId) return exam;
    }
    return null;
  }

  int get todayLearningSeconds => _todaySeconds(CultivationType.learning);
  int get todayExerciseSeconds => _todaySeconds(CultivationType.exercise);

  List<DailyCultivationSummary> get recentDailySummaries {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List<DateTime>.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final totals = <String, List<int>>{
      for (final date in dates) _dateKey(date): [0, 0],
    };

    for (final session in recentSessions) {
      final localDate = session.endedAt.toLocal();
      final key = _dateKey(localDate);
      final total = totals[key];
      if (total == null) continue;
      total[session.type == CultivationType.learning ? 0 : 1] +=
          session.durationSeconds;
    }

    return [
      for (final date in dates)
        DailyCultivationSummary(
          date: date,
          learningSeconds: totals[_dateKey(date)]![0],
          exerciseSeconds: totals[_dateKey(date)]![1],
        ),
    ];
  }

  int _todaySeconds(CultivationType type) {
    final now = DateTime.now();
    return recentSessions
        .where(
          (session) =>
              session.type == type &&
              session.endedAt.toLocal().year == now.year &&
              session.endedAt.toLocal().month == now.month &&
              session.endedAt.toLocal().day == now.day,
        )
        .fold(0, (total, session) => total + session.durationSeconds);
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}

class DailyCultivationSummary {
  const DailyCultivationSummary({
    required this.date,
    required this.learningSeconds,
    required this.exerciseSeconds,
  });

  final DateTime date;
  final int learningSeconds;
  final int exerciseSeconds;
}

void invalidateCultivationData(WidgetRef ref) {
  ref.invalidate(cultivationDashboardProvider);
  ref.invalidate(techniqueDetailProvider);
  ref.invalidate(techniqueSessionsProvider);
  ref.invalidate(techniqueHistoryProvider);
}
