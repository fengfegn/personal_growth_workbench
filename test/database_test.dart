import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/features/profile/data/user_profile_repository.dart';
import 'package:personal_growth_workbench/features/goals/data/goal_repository.dart';
import 'package:personal_growth_workbench/features/goals/domain/goal.dart';
import 'package:personal_growth_workbench/features/tasks/data/task_repository.dart';
import 'package:personal_growth_workbench/features/tasks/domain/task.dart';
import 'package:personal_growth_workbench/core/time/local_date.dart';
import 'package:personal_growth_workbench/features/hotspots/data/hotspot_repository.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/hotspot.dart';
import 'package:personal_growth_workbench/features/calendar/data/calendar_event_repository.dart';
import 'package:personal_growth_workbench/features/calendar/domain/calendar_event.dart';

void main() {
  test('creates the Version 11 Drift schema and stores settings', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'theme',
            valueJson: '"yuan1"',
            updatedAt: DateTime.utc(2026, 8, 4),
          ),
        );

    final setting = await database.select(database.appSettings).getSingle();
    expect(database.schemaVersion, 11);
    expect(setting.key, 'theme');
    expect(setting.valueJson, '"yuan1"');
  });

  test(
    'stores recurring calendar events and calculates next occurrence',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = CalendarEventRepository(database);

      final event = await repository.createEvent(
        title: '妈妈生日',
        type: CalendarEventType.birthday,
        eventDate: '1990-02-28',
        notes: '准备礼物',
      );

      expect(event.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(event.daysUntil(DateTime(2026, 3, 1)), 364);
      expect((await repository.getEvents()).single.notes, '准备礼物');

      await repository.softDelete(event.id);
      expect(await repository.getEvents(), isEmpty);
    },
  );

  test('creates and updates the local user nickname', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = UserProfileRepository(database);

    final initial = await repository.getOrCreate();
    final updated = await repository.updateNickname('小明');

    expect(initial.nickname, '你的昵称');
    expect(updated.nickname, '小明');
    expect((await repository.getOrCreate()).nickname, '小明');
  });

  test(
    'supports goal hierarchy, progress, milestones, and task links',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final goalRepository = GoalRepository(database);
      final parent = await goalRepository.createGoal(
        title: 'Finish the degree',
        type: GoalType.longTerm,
        targetDate: '2027-06-30',
        successCriteria: 'Submit the thesis',
      );
      final child = await goalRepository.createGoal(
        title: 'Complete proposal',
        type: GoalType.shortTerm,
        parentGoalId: parent.id,
        progress: 25,
      );
      final milestone = await goalRepository.createMilestone(
        goalId: child.id,
        title: 'Proposal approved',
        targetDate: '2026-09-30',
      );
      final task = await TaskRepository(
        database,
      ).createTask(title: 'Draft proposal', goalId: child.id);

      expect(
        (await goalRepository.getActiveGoals()).map((item) => item.title),
        containsAll(['Finish the degree', 'Complete proposal']),
      );
      expect(task.goalId, child.id);
      expect(
        (await goalRepository.getMilestones(child.id)).single.id,
        milestone.id,
      );

      await goalRepository.toggleMilestone(milestone.id, true);
      await goalRepository.updateProgress(child.id, 60);
      expect(
        (await goalRepository.getMilestones(child.id)).single.isCompleted,
        true,
      );
      expect((await goalRepository.getGoal(child.id)).progress, 60);

      await goalRepository.softDelete(parent.id);
      expect(await goalRepository.getActiveGoals(), isEmpty);
    },
  );

  test('supports task CRUD, status changes, and soft deletion', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = TaskRepository(database);

    final created = await repository.createTask(
      title: '完成 Phase 1',
      notes: '先完成本地闭环',
      scheduledDate: '2026-08-04',
      priority: TaskPriority.red.storage,
      dueAt: DateTime(2026, 8, 10, 23, 59, 59),
    );
    final updated = await repository.updateTask(
      id: created.id,
      title: '完成 Phase 1 本地闭环',
      notes: '已更新',
      scheduledDate: '2026-08-05',
      priority: TaskPriority.yellow.storage,
      dueAt: DateTime(2026, 8, 11, 23, 59, 59),
    );
    final completed = await repository.setStatus(
      updated.id,
      TaskStatus.completed,
    );

    expect(completed.title, '完成 Phase 1 本地闭环');
    expect(completed.status, TaskStatus.completed);
    expect(completed.completedAt, isNotNull);
    expect(completed.priority, TaskPriority.yellow.storage);
    expect(completed.dueAt, DateTime(2026, 8, 11, 23, 59, 59));

    await repository.softDelete(completed.id);
    expect(await repository.getActiveTasks(), isEmpty);
  });

  test('syncs goal progress from linked task completion', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final goalRepository = GoalRepository(database);
    final taskRepository = TaskRepository(database);
    final goal = await goalRepository.createGoal(
      title: 'Complete the research plan',
      type: GoalType.shortTerm,
      progress: 35,
    );
    final firstTask = await taskRepository.createTask(
      title: 'Draft the outline',
      goalId: goal.id,
    );
    final secondTask = await taskRepository.createTask(
      title: 'Review the outline',
      goalId: goal.id,
    );

    expect((await goalRepository.getGoal(goal.id)).progress, 0);

    await taskRepository.setStatus(firstTask.id, TaskStatus.completed);
    expect((await goalRepository.getGoal(goal.id)).progress, 50);

    await taskRepository.setStatus(secondTask.id, TaskStatus.completed);
    expect((await goalRepository.getGoal(goal.id)).progress, 100);

    await taskRepository.setStatus(firstTask.id, TaskStatus.todo);
    expect((await goalRepository.getGoal(goal.id)).progress, 50);
  });

  test(
    'syncs goal progress from milestones when no tasks are linked',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final goalRepository = GoalRepository(database);
      final goal = await goalRepository.createGoal(
        title: 'Publish the article',
        type: GoalType.shortTerm,
        progress: 20,
      );
      final milestone = await goalRepository.createMilestone(
        goalId: goal.id,
        title: 'Submit the draft',
      );

      expect((await goalRepository.getGoal(goal.id)).progress, 0);
      await goalRepository.toggleMilestone(milestone.id, true);
      expect((await goalRepository.getGoal(goal.id)).progress, 100);
      await goalRepository.toggleMilestone(milestone.id, false);
      expect((await goalRepository.getGoal(goal.id)).progress, 0);
    },
  );

  test(
    'hides completed tasks after their scheduled day in the current list',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = TaskRepository(database);
      final today = DateTime.now();
      final todayDate = localDateKey(today);
      final yesterdayDate = localDateKey(
        today.subtract(const Duration(days: 1)),
      );
      final tomorrowDate = localDateKey(today.add(const Duration(days: 1)));

      final completedYesterday = await repository.createTask(
        title: 'completed yesterday',
        scheduledDate: yesterdayDate,
      );
      final completedToday = await repository.createTask(
        title: 'completed today',
        scheduledDate: todayDate,
      );
      final completedTomorrow = await repository.createTask(
        title: 'completed tomorrow',
        scheduledDate: tomorrowDate,
      );
      await repository.createTask(
        title: 'open yesterday',
        scheduledDate: yesterdayDate,
      );
      await repository.setStatus(completedYesterday.id, TaskStatus.completed);
      await repository.setStatus(completedToday.id, TaskStatus.completed);
      await repository.setStatus(completedTomorrow.id, TaskStatus.completed);

      final currentTasks = await repository.getActiveTasks(
        hideCompletedBeforeToday: true,
      );

      expect(
        currentTasks.map((task) => task.title),
        containsAll([
          'completed today',
          'completed tomorrow',
          'open yesterday',
        ]),
      );
      expect(
        currentTasks.map((task) => task.title),
        isNot(contains('completed yesterday')),
      );
      expect(
        (await repository.getActiveTasks(
          scheduledDate: yesterdayDate,
        )).map((task) => task.title),
        containsAll(['completed yesterday', 'open yesterday']),
      );
    },
  );

  test('persists daily hotspots with category and source references', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = HotspotRepository(database);
    const source = HotspotSource(
      name: 'Source A',
      url: 'https://example.com/article-a',
      publishedAt: null,
    );
    const draft = HotspotDraft(
      category: HotspotCategory.technology,
      title: 'Technology update',
      summary: 'A verified summary.',
      analysis: 'A measured analysis.',
      keyPoints: ['First point'],
      sources: [source],
      confidence: HotspotConfidence.high,
    );

    await repository.replaceForDate(
      localDate: '2026-08-07',
      drafts: const [draft],
      provider: 'ChatGPT',
      model: 'test-model',
    );

    final saved = await repository.getForDate('2026-08-07');
    expect(saved.single.category, HotspotCategory.technology);
    expect(saved.single.sources.single.url, source.url);
    expect(saved.single.provider, 'ChatGPT');
    expect(saved.single.model, 'test-model');
    expect(saved.single.analysis, 'A measured analysis.');
  });

  test(
    'keeps up to three daily top task slots and preserves removal',
    () async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final repository = TaskRepository(database);
      const date = '2026-08-04';
      final tasks = [
        await repository.createTask(title: '第一件事', scheduledDate: date),
        await repository.createTask(title: '第二件事', scheduledDate: date),
        await repository.createTask(title: '第三件事', scheduledDate: date),
      ];

      for (var index = 0; index < tasks.length; index++) {
        await repository.assignTopTask(
          localDate: date,
          slot: index + 1,
          taskId: tasks[index].id,
        );
      }

      final selected = await repository.getTopTasks(date);
      expect(selected.map((item) => item.slot), [1, 2, 3]);
      expect(selected.map((item) => item.task.title), ['第一件事', '第二件事', '第三件事']);

      await repository.unassignTopTask(localDate: date, slot: 2);
      expect((await repository.getTopTasks(date)).map((item) => item.slot), [
        1,
        3,
      ]);
    },
  );
}
