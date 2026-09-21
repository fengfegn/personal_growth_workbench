import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart'
    hide CultivationProfile, CultivationSession;
import 'package:personal_growth_workbench/features/cultivation/application/cultivation_providers.dart';
import 'package:personal_growth_workbench/features/cultivation/data/cultivation_repository.dart';
import 'package:personal_growth_workbench/features/cultivation/domain/cultivation.dart';
import 'package:personal_growth_workbench/features/cultivation/domain/cultivation_settlement.dart';

void main() {
  test('aggregates learning and exercise by the last seven local days', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dashboard = CultivationDashboardData(
      profile: const CultivationProfile(
        id: 'profile',
        currentRealm: 0,
        mentalPoints: 0,
        physicalPoints: 0,
        mentalProgressSeconds: 0,
        physicalProgressSeconds: 0,
      ),
      techniques: const [],
      activeExams: const [],
      activeRealmTrial: null,
      realmHistory: const [],
      recentSessions: [
        _session(
          id: 'today-learning',
          type: CultivationType.learning,
          endedAt: today.add(const Duration(hours: 9)),
          durationSeconds: 1800,
        ),
        _session(
          id: 'yesterday-learning',
          type: CultivationType.learning,
          endedAt: yesterday.add(const Duration(hours: 9)),
          durationSeconds: 1200,
        ),
        _session(
          id: 'yesterday-exercise',
          type: CultivationType.exercise,
          endedAt: yesterday.add(const Duration(hours: 18)),
          durationSeconds: 2400,
        ),
      ],
    );

    final summaries = dashboard.recentDailySummaries;
    expect(summaries, hasLength(7));
    expect(summaries.last.learningSeconds, 1800);
    expect(summaries.last.exerciseSeconds, 0);
    expect(summaries[5].learningSeconds, 1200);
    expect(summaries[5].exerciseSeconds, 2400);
  });

  test('settlement carries 30 minute learning progress across sessions', () {
    var result = settleCultivationSession(
      type: CultivationType.learning,
      durationSeconds: 1800,
      mentalProgressSeconds: 0,
      physicalProgressSeconds: 0,
    );
    expect(result.mentalPoints, 0);
    expect(result.mentalProgressSeconds, 1800);

    result = settleCultivationSession(
      type: CultivationType.learning,
      durationSeconds: 1800,
      mentalProgressSeconds: result.mentalProgressSeconds,
      physicalProgressSeconds: 0,
    );
    expect(result.mentalPoints, 1);
    expect(result.mentalProgressSeconds, 0);
  });

  test('technique progress is independent from mental progress', () {
    final result = settleCultivationSession(
      type: CultivationType.learning,
      durationSeconds: 1800,
      mentalProgressSeconds: 0,
      physicalProgressSeconds: 0,
      proficiencyProgressSeconds: 1800,
      proficiency: 2,
      techniqueId: 'flutter',
    );
    expect(result.mentalProgressSeconds, 1800);
    expect(result.mentalPoints, 0);
    expect(result.proficiency, 3);
    expect(result.proficiencyProgressSeconds, 0);
  });

  test('exercise increases physical progress only', () {
    final result = settleCultivationSession(
      type: CultivationType.exercise,
      durationSeconds: 3600,
      mentalProgressSeconds: 120,
      physicalProgressSeconds: 0,
      techniqueId: 'ignored-for-exercise',
    );
    expect(result.physicalPoints, 1);
    expect(result.mentalPoints, 0);
    expect(result.mentalProgressSeconds, 120);
    expect(result.proficiency, 0);
  });

  test('repository settles a session once and preserves remainder', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = CultivationRepository(database);
    final technique = await repository.createTechnique(name: 'Flutter');
    final started = DateTime.utc(2026, 8, 25);

    await repository.finishSession(
      id: 'session-a',
      type: CultivationType.learning,
      techniqueId: technique.id,
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 30)),
      durationSeconds: 1800,
    );
    await repository.finishSession(
      id: 'session-b',
      type: CultivationType.learning,
      techniqueId: technique.id,
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 60)),
      durationSeconds: 1800,
    );
    await repository.finishSession(
      id: 'session-b',
      type: CultivationType.learning,
      techniqueId: technique.id,
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 60)),
      durationSeconds: 1800,
    );

    final profile = await repository.getProfile();
    final savedTechnique = await repository.getTechnique(technique.id);
    final sessions = await repository.getRecentSessions(
      techniqueId: technique.id,
    );
    expect(profile.mentalPoints, 1);
    expect(profile.mentalProgressSeconds, 0);
    expect(savedTechnique.proficiency, 1);
    expect(savedTechnique.proficiencyProgressSeconds, 0);
    expect(sessions, hasLength(2));
  });

  test(
    'passed exam advances technique and writes history atomically',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = CultivationRepository(database);
      final technique = await repository.createTechnique(name: 'Python');
      final started = DateTime.utc(2026, 8, 25);
      for (var index = 0; index < 10; index++) {
        await repository.finishSession(
          id: 'python-$index',
          type: CultivationType.learning,
          techniqueId: technique.id,
          startedAt: started,
          endedAt: started.add(const Duration(hours: 1)),
          durationSeconds: 3600,
        );
      }

      final eligible = await repository.getTechnique(technique.id);
      expect(eligible.canAdvance(), isTrue);
      final exam = await repository.createExam(
        techniqueId: technique.id,
        title: '数据处理小项目',
        objective: '读取并处理真实数据',
        acceptanceCriteria: '有输出并处理异常',
      );
      await repository.setExamStatus(exam.id, ExamStatus.inProgress);
      await repository.setExamStatus(exam.id, ExamStatus.pendingReview);
      await repository.passExam(exam.id);

      final advanced = await repository.getTechnique(technique.id);
      final savedExam = await repository.getExam(exam.id);
      final history = await repository.getAdvancementHistory(technique.id);
      expect(advanced.level, 1);
      expect(savedExam.status, ExamStatus.passed);
      expect(history, hasLength(1));
      expect(history.single.toLevel, 1);
    },
  );
}

CultivationSession _session({
  required String id,
  required CultivationType type,
  required DateTime endedAt,
  required int durationSeconds,
}) {
  return CultivationSession(
    id: id,
    type: type,
    techniqueId: null,
    startedAt: endedAt.subtract(Duration(seconds: durationSeconds)),
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    mentalGained: 0,
    physicalGained: 0,
    proficiencyGained: 0,
    note: null,
    settled: true,
    createdAt: endedAt,
  );
}
