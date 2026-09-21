import '../../../core/database/app_database.dart';

enum TaskPriority {
  red(2, '红色', '重要且紧急'),
  yellow(1, '黄色', '重要或紧急'),
  green(0, '绿色', '普通');

  const TaskPriority(this.storage, this.label, this.description);

  final int storage;
  final String label;
  final String description;

  static TaskPriority fromStorage(int value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.storage == value,
      orElse: () => TaskPriority.green,
    );
  }
}

enum TaskStatus {
  todo('待开始'),
  inProgress('进行中'),
  completed('已完成'),
  postponed('已延期'),
  cancelled('已取消');

  const TaskStatus(this.label);

  final String label;

  static TaskStatus fromStorage(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TaskStatus.todo,
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.scheduledDate,
    required this.createdAt,
    required this.updatedAt,
    this.goalId,
    this.notes,
    this.dueAt,
    this.estimatedMinutes,
    this.completedAt,
    this.slot,
  });

  factory TaskItem.fromRow(Task row, {int? slot}) {
    return TaskItem(
      id: row.id,
      title: row.title,
      status: TaskStatus.fromStorage(row.status),
      priority: row.priority,
      scheduledDate: row.scheduledDate,
      goalId: row.goalId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      notes: row.notes,
      dueAt: row.dueAt,
      estimatedMinutes: row.estimatedMinutes,
      completedAt: row.completedAt,
      slot: slot,
    );
  }

  final String id;
  final String title;
  final TaskStatus status;
  final int priority;
  final String? scheduledDate;
  final String? goalId;
  final String? notes;
  final DateTime? dueAt;
  final int? estimatedMinutes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? slot;

  bool get isCompleted => status == TaskStatus.completed;

  TaskPriority get priorityLevel => TaskPriority.fromStorage(priority);
}

class TopTaskItem {
  const TopTaskItem({required this.slot, required this.task});

  final int slot;
  final TaskItem task;
}
