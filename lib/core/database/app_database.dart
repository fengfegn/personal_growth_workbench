import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get valueJson => text().named('value_json')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {key};
}

class UserProfiles extends Table {
  TextColumn get id => text()();

  TextColumn get nickname => text()();

  TextColumn get timezone => text().withDefault(const Constant('UTC'))();

  TextColumn get locale => text().withDefault(const Constant('zh_CN'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('todo'))();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  TextColumn get scheduledDate => text().named('scheduled_date').nullable()();

  TextColumn get goalId => text().named('goal_id').nullable()();

  DateTimeColumn get dueAt => dateTime().named('due_at').nullable()();

  IntColumn get estimatedMinutes =>
      integer().named('estimated_minutes').nullable()();

  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text()();

  TextColumn get parentGoalId => text().named('parent_goal_id').nullable()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  TextColumn get goalType =>
      text().named('goal_type').withDefault(const Constant('long_term'))();

  TextColumn get startDate => text().named('start_date').nullable()();

  TextColumn get targetDate => text().named('target_date').nullable()();

  TextColumn get status => text().withDefault(const Constant('active'))();

  IntColumn get progress => integer().withDefault(const Constant(0))();

  TextColumn get meaning => text().nullable()();

  TextColumn get successCriteria =>
      text().named('success_criteria').nullable()();

  TextColumn get pauseReason => text().named('pause_reason').nullable()();

  TextColumn get completionSummary =>
      text().named('completion_summary').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class GoalMilestones extends Table {
  TextColumn get id => text()();

  TextColumn get goalId => text().named('goal_id')();

  TextColumn get title => text()();

  TextColumn get targetDate => text().named('target_date').nullable()();

  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  IntColumn get sortOrder => integer().named('sort_order')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyTopTasks extends Table {
  TextColumn get id => text()();

  TextColumn get localDate => text().named('local_date')();

  IntColumn get slot => integer()();

  TextColumn get taskId => text().named('task_id')();

  DateTimeColumn get selectedAt => dateTime().named('selected_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class QuickNotes extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().nullable()();

  TextColumn get contentJson => text().named('content_json')();

  TextColumn get localDate => text().named('local_date')();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class QuickNoteTags extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class QuickNoteTagLinks extends Table {
  TextColumn get id => text()();

  TextColumn get noteId => text().named('note_id')();

  TextColumn get tagId => text().named('tag_id')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class QuickNoteBlocks extends Table {
  TextColumn get id => text()();

  TextColumn get noteId => text().named('note_id')();

  TextColumn get blockType => text().named('block_type')();

  TextColumn get value => text()();

  IntColumn get sortOrder => integer().named('sort_order')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyHotspots extends Table {
  TextColumn get id => text()();

  TextColumn get localDate => text().named('local_date')();

  TextColumn get category => text()();

  TextColumn get title => text()();

  TextColumn get summary => text()();

  TextColumn get analysis => text().withDefault(const Constant(''))();

  TextColumn get keyPointsJson => text().named('key_points_json')();

  TextColumn get sourcesJson => text().named('sources_json')();

  TextColumn get confidence => text().withDefault(const Constant('medium'))();

  TextColumn get provider => text().nullable()();

  TextColumn get model => text().nullable()();

  DateTimeColumn get generatedAt => dateTime().named('generated_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CalendarEvents extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get eventType =>
      text().named('event_type').withDefault(const Constant('important_day'))();

  TextColumn get eventDate => text().named('event_date')();

  BoolColumn get repeatsYearly =>
      boolean().named('repeats_yearly').withDefault(const Constant(true))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Courses extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get teacher => text().nullable()();

  TextColumn get classroom => text().nullable()();

  TextColumn get color => text().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class CourseSessions extends Table {
  TextColumn get id => text()();

  TextColumn get courseId => text().named('course_id')();

  TextColumn get date => text()();

  TextColumn get startTime => text().named('start_time')();

  TextColumn get endTime => text().named('end_time')();

  IntColumn get slotStart => integer().named('slot_start').nullable()();

  IntColumn get slotEnd => integer().named('slot_end').nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  TextColumn get originDeviceId =>
      text().named('origin_device_id').withDefault(const Constant('local'))();

  @override
  Set<Column> get primaryKey => {id};
}

class CultivationProfiles extends Table {
  TextColumn get id => text()();

  IntColumn get currentRealm =>
      integer().named('current_realm').withDefault(const Constant(0))();

  IntColumn get mentalPoints =>
      integer().named('mental_points').withDefault(const Constant(0))();

  IntColumn get physicalPoints =>
      integer().named('physical_points').withDefault(const Constant(0))();

  IntColumn get mentalProgressSeconds => integer()
      .named('mental_progress_seconds')
      .withDefault(const Constant(0))();

  IntColumn get physicalProgressSeconds => integer()
      .named('physical_progress_seconds')
      .withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class Techniques extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get category => text().nullable()();

  IntColumn get level => integer().withDefault(const Constant(0))();

  IntColumn get proficiency => integer().withDefault(const Constant(0))();

  IntColumn get proficiencyProgressSeconds => integer()
      .named('proficiency_progress_seconds')
      .withDefault(const Constant(0))();

  IntColumn get totalSeconds =>
      integer().named('total_seconds').withDefault(const Constant(0))();

  TextColumn get status => text().withDefault(const Constant('active'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CultivationSessions extends Table {
  TextColumn get id => text()();

  TextColumn get type => text()();

  TextColumn get techniqueId => text().named('technique_id').nullable()();

  DateTimeColumn get startedAt => dateTime().named('started_at')();

  DateTimeColumn get endedAt => dateTime().named('ended_at')();

  IntColumn get durationSeconds =>
      integer().named('duration_seconds').withDefault(const Constant(0))();

  IntColumn get mentalGained =>
      integer().named('mental_gained').withDefault(const Constant(0))();

  IntColumn get physicalGained =>
      integer().named('physical_gained').withDefault(const Constant(0))();

  IntColumn get proficiencyGained =>
      integer().named('proficiency_gained').withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  BoolColumn get settled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class AdvancementExams extends Table {
  TextColumn get id => text()();

  TextColumn get techniqueId => text().named('technique_id')();

  IntColumn get fromLevel => integer().named('from_level')();

  IntColumn get toLevel => integer().named('to_level')();

  TextColumn get title => text()();

  TextColumn get objective => text()();

  TextColumn get acceptanceCriteria => text().named('acceptance_criteria')();

  TextColumn get note => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('notStarted'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get submittedAt =>
      dateTime().named('submitted_at').nullable()();

  DateTimeColumn get reviewedAt => dateTime().named('reviewed_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AdvancementHistories extends Table {
  TextColumn get id => text()();

  TextColumn get techniqueId => text().named('technique_id')();

  IntColumn get fromLevel => integer().named('from_level')();

  IntColumn get toLevel => integer().named('to_level')();

  TextColumn get examId => text().named('exam_id')();

  DateTimeColumn get advancedAt => dateTime().named('advanced_at')();
}

class RealmTrials extends Table {
  TextColumn get id => text()();

  IntColumn get fromRealm => integer().named('from_realm')();

  IntColumn get toRealm => integer().named('to_realm')();

  TextColumn get title => text()();

  TextColumn get objective => text()();

  TextColumn get acceptanceCriteria => text().named('acceptance_criteria')();

  TextColumn get note => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('notStarted'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get startedAt => dateTime().named('started_at').nullable()();

  DateTimeColumn get submittedAt =>
      dateTime().named('submitted_at').nullable()();

  DateTimeColumn get reviewedAt => dateTime().named('reviewed_at').nullable()();

  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RealmAdvancementHistories extends Table {
  TextColumn get id => text()();

  IntColumn get fromRealm => integer().named('from_realm')();

  IntColumn get toRealm => integer().named('to_realm')();

  TextColumn get trialId => text().named('trial_id')();

  IntColumn get mentalAtBreakthrough =>
      integer().named('mental_at_breakthrough')();

  IntColumn get physicalAtBreakthrough =>
      integer().named('physical_at_breakthrough')();

  DateTimeColumn get advancedAt => dateTime().named('advanced_at')();

  @override
  Set<Column> get primaryKey => {id};
}

class Habits extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get icon => text().withDefault(const Constant('●'))();

  TextColumn get color => text().withDefault(const Constant('primary'))();

  TextColumn get frequency => text().withDefault(const Constant('daily'))();

  TextColumn get startDate => text().named('start_date')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class HabitCheckins extends Table {
  TextColumn get id => text()();

  TextColumn get habitId => text().named('habit_id')();

  TextColumn get date => text()();

  DateTimeColumn get completedAt => dateTime().named('completed_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, date},
  ];
}

@DriftDatabase(
  tables: [
    AppSettings,
    UserProfiles,
    Tasks,
    Goals,
    GoalMilestones,
    DailyTopTasks,
    QuickNotes,
    QuickNoteTags,
    QuickNoteTagLinks,
    QuickNoteBlocks,
    DailyHotspots,
    CalendarEvents,
    Courses,
    CourseSessions,
    CultivationProfiles,
    Techniques,
    CultivationSessions,
    AdvancementExams,
    AdvancementHistories,
    RealmTrials,
    RealmAdvancementHistories,
    Habits,
    HabitCheckins,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 1) {
        await m.createTable(appSettings);
      }
      if (from < 2) {
        await m.createTable(userProfiles);
        await m.createTable(tasks);
        await m.createTable(dailyTopTasks);
      }
      if (from < 3) {
        await m.addColumn(tasks, tasks.goalId);
        await m.createTable(goals);
        await m.createTable(goalMilestones);
      }
      if (from < 4) {
        await m.createTable(quickNotes);
        await m.createTable(quickNoteTags);
        await m.createTable(quickNoteTagLinks);
        await m.createTable(quickNoteBlocks);
      }
      if (from < 5) {
        await m.createTable(dailyHotspots);
      }
      if (from < 6) {
        await m.addColumn(dailyHotspots, dailyHotspots.analysis);
      }
      if (from < 7) {
        await m.createTable(calendarEvents);
      }
      if (from < 8) {
        await m.createTable(cultivationProfiles);
        await m.createTable(techniques);
        await m.createTable(cultivationSessions);
        await m.createTable(advancementExams);
        await m.createTable(advancementHistories);
      }
      if (from < 9) {
        await m.addColumn(
          cultivationProfiles,
          cultivationProfiles.currentRealm,
        );
        await m.createTable(realmTrials);
        await m.createTable(realmAdvancementHistories);
      }
      if (from < 10) {
        await m.createTable(courses);
        await m.createTable(courseSessions);
      }
      if (from < 11) {
        await m.createTable(habits);
        await m.createTable(habitCheckins);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      path.join(directory.path, 'personal_growth_workbench.sqlite'),
    );
    return NativeDatabase(file);
  });
}
