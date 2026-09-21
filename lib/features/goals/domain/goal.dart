import '../../../core/database/app_database.dart';

enum GoalType {
  longTerm('long_term', '长期目标'),
  yearly('yearly', '年度目标'),
  quarterly('quarterly', '季度目标'),
  monthly('monthly', '月度目标'),
  shortTerm('short_term', '短期目标');

  const GoalType(this.storage, this.label);

  final String storage;
  final String label;

  static GoalType fromStorage(String value) {
    return GoalType.values.firstWhere(
      (type) => type.storage == value,
      orElse: () => GoalType.longTerm,
    );
  }
}

enum GoalStatus {
  active('active', '进行中'),
  paused('paused', '已暂停'),
  completed('completed', '已完成'),
  abandoned('abandoned', '已放弃');

  const GoalStatus(this.storage, this.label);

  final String storage;
  final String label;

  static GoalStatus fromStorage(String value) {
    return GoalStatus.values.firstWhere(
      (status) => status.storage == value,
      orElse: () => GoalStatus.active,
    );
  }
}

class GoalItem {
  const GoalItem({
    required this.id,
    required this.parentGoalId,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.targetDate,
    required this.status,
    required this.progress,
    required this.meaning,
    required this.successCriteria,
    required this.pauseReason,
    required this.completionSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalItem.fromRow(Goal row) {
    return GoalItem(
      id: row.id,
      parentGoalId: row.parentGoalId,
      title: row.title,
      description: row.description,
      type: GoalType.fromStorage(row.goalType),
      startDate: row.startDate,
      targetDate: row.targetDate,
      status: GoalStatus.fromStorage(row.status),
      progress: row.progress,
      meaning: row.meaning,
      successCriteria: row.successCriteria,
      pauseReason: row.pauseReason,
      completionSummary: row.completionSummary,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  final String id;
  final String? parentGoalId;
  final String title;
  final String? description;
  final GoalType type;
  final String? startDate;
  final String? targetDate;
  final GoalStatus status;
  final int progress;
  final String? meaning;
  final String? successCriteria;
  final String? pauseReason;
  final String? completionSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFinished =>
      status == GoalStatus.completed || status == GoalStatus.abandoned;
}

class GoalMilestoneItem {
  const GoalMilestoneItem({
    required this.id,
    required this.goalId,
    required this.title,
    required this.targetDate,
    required this.completedAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalMilestoneItem.fromRow(GoalMilestone row) {
    return GoalMilestoneItem(
      id: row.id,
      goalId: row.goalId,
      title: row.title,
      targetDate: row.targetDate,
      completedAt: row.completedAt,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  final String id;
  final String goalId;
  final String title;
  final String? targetDate;
  final DateTime? completedAt;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => completedAt != null;
}
