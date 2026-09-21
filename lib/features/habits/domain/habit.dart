import '../../../core/database/app_database.dart';

class HabitItem {
  const HabitItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.frequency,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  factory HabitItem.fromRow(Habit row) {
    return HabitItem(
      id: row.id,
      name: row.name,
      description: row.description,
      icon: row.icon,
      color: row.color,
      frequency: row.frequency,
      startDate: row.startDate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      archivedAt: row.archivedAt,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String frequency;
  final String startDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool isActiveOn(String date) {
    if (startDate.compareTo(date) > 0) return false;
    final archivedDate = archivedAt == null
        ? null
        : '${archivedAt!.toLocal().year.toString().padLeft(4, '0')}-'
              '${archivedAt!.toLocal().month.toString().padLeft(2, '0')}-'
              '${archivedAt!.toLocal().day.toString().padLeft(2, '0')}';
    return archivedDate == null || date.compareTo(archivedDate) < 0;
  }

  bool get isArchived => archivedAt != null;
}

class HabitCheckinItem {
  const HabitCheckinItem({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completedAt,
    required this.createdAt,
  });

  factory HabitCheckinItem.fromRow(HabitCheckin row) {
    return HabitCheckinItem(
      id: row.id,
      habitId: row.habitId,
      date: row.date,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
    );
  }

  final String id;
  final String habitId;
  final String date;
  final DateTime completedAt;
  final DateTime createdAt;
}
