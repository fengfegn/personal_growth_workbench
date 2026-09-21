import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/cultivation/data/cultivation_repository.dart';
import 'package:personal_growth_workbench/features/cultivation/domain/cultivation.dart';
import 'package:personal_growth_workbench/features/cultivation/domain/realm.dart';

void main() {
  test('requires both mental and physical thresholds', () {
    expect(
      canAttemptRealmBreakthrough(
        currentRealm: 0,
        mentalPoints: 10,
        physicalPoints: 4,
        hasActiveTrial: false,
      ),
      isFalse,
    );
    expect(
      canAttemptRealmBreakthrough(
        currentRealm: 0,
        mentalPoints: 9,
        physicalPoints: 5,
        hasActiveTrial: false,
      ),
      isFalse,
    );
    expect(
      canAttemptRealmBreakthrough(
        currentRealm: 0,
        mentalPoints: 10,
        physicalPoints: 5,
        hasActiveTrial: false,
      ),
      isTrue,
    );
  });

  test(
    'uses the weakest attribute for realm progress and estimates remainder',
    () {
      final progress = calculateRealmProgress(
        currentRealm: 4,
        mentalPoints: 140,
        physicalPoints: 30,
        mentalProgressSeconds: 0,
        physicalProgressSeconds: 1800,
      );
      expect(progress.realm?.name, '观山');
      expect(progress.overallRatio, closeTo(30 / 55, 0.001));
      expect(progress.bottleneck, RealmBottleneck.physical);
      expect(progress.mentalRemaining, 10);
      expect(progress.physicalRemaining, 25);
      expect(progress.mentalTrainingSeconds, 10 * 3600);
      expect(progress.physicalTrainingSeconds, 25 * 3600 - 1800);
    },
  );

  test(
    'realm trial pass preserves attributes and creates one history',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = CultivationRepository(database);
      for (var index = 0; index < 10; index++) {
        await repository.finishSession(
          id: 'realm-learning-$index',
          type: CultivationType.learning,
          startedAt: DateTime.utc(2026, 8, 25),
          endedAt: DateTime.utc(2026, 8, 25, 1),
          durationSeconds: 3600,
        );
      }
      for (var index = 0; index < 5; index++) {
        await repository.finishSession(
          id: 'realm-exercise-$index',
          type: CultivationType.exercise,
          startedAt: DateTime.utc(2026, 8, 25),
          endedAt: DateTime.utc(2026, 8, 25, 1),
          durationSeconds: 3600,
        );
      }

      final before = await repository.getProfile();
      expect(before.currentRealm, 0);
      expect(before.mentalPoints, 10);
      expect(before.physicalPoints, 5);
      final trial = await repository.createRealmTrial(
        title: '连续一周修炼',
        objective: '持续完成修炼',
        acceptanceCriteria: '有完整记录',
      );
      await repository.setRealmTrialStatus(
        trial.id,
        RealmTrialStatus.inProgress,
      );
      await repository.setRealmTrialStatus(
        trial.id,
        RealmTrialStatus.pendingReview,
      );
      await repository.passRealmTrial(trial.id);
      await expectLater(
        repository.passRealmTrial(trial.id),
        throwsA(isA<StateError>()),
      );

      final after = await repository.getProfile();
      final savedTrial = (await repository.getRealmTrial(trial.id))!;
      final history = await repository.getRealmAdvancementHistory();
      expect(after.currentRealm, 1);
      expect(after.mentalPoints, before.mentalPoints);
      expect(after.physicalPoints, before.physicalPoints);
      expect(savedTrial.status, RealmTrialStatus.passed);
      expect(history, hasLength(1));
      expect(history.single.trialId, trial.id);
    },
  );

  test('failed trial does not change realm or attributes', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = CultivationRepository(database);
    for (var index = 0; index < 10; index++) {
      await repository.finishSession(
        id: 'failed-learning-$index',
        type: CultivationType.learning,
        startedAt: DateTime.utc(2026, 8, 25),
        endedAt: DateTime.utc(2026, 8, 25, 1),
        durationSeconds: 3600,
      );
    }
    for (var index = 0; index < 5; index++) {
      await repository.finishSession(
        id: 'failed-exercise-$index',
        type: CultivationType.exercise,
        startedAt: DateTime.utc(2026, 8, 25),
        endedAt: DateTime.utc(2026, 8, 25, 1),
        durationSeconds: 3600,
      );
    }
    final trial = await repository.createRealmTrial(
      title: '试炼',
      objective: '目标',
      acceptanceCriteria: '标准',
    );
    await repository.setRealmTrialStatus(trial.id, RealmTrialStatus.inProgress);
    await repository.setRealmTrialStatus(
      trial.id,
      RealmTrialStatus.pendingReview,
    );
    await repository.failRealmTrial(trial.id);

    final profile = await repository.getProfile();
    expect(profile.currentRealm, 0);
    expect(profile.mentalPoints, 10);
    expect(profile.physicalPoints, 5);
    expect(
      (await repository.getRealmTrial(trial.id))!.status,
      RealmTrialStatus.failed,
    );
  });

  test('highest realm has no next target or breakthrough eligibility', () {
    expect(getNextRealm(userRealms.last.index), isNull);
    expect(
      canAttemptRealmBreakthrough(
        currentRealm: userRealms.last.index,
        mentalPoints: 9999,
        physicalPoints: 9999,
        hasActiveTrial: false,
      ),
      isFalse,
    );
    final progress = calculateRealmProgress(
      currentRealm: userRealms.last.index,
      mentalPoints: 9999,
      physicalPoints: 9999,
      mentalProgressSeconds: 0,
      physicalProgressSeconds: 0,
    );
    expect(progress.overallRatio, 1);
    expect(progress.realm, isNull);
  });
}
