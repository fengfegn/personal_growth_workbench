import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/course_repository.dart';
import '../domain/course.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(ref.watch(appDatabaseProvider));
});

final courseWeekProvider = FutureProvider.family<CourseWeek, DateTime>((
  ref,
  weekStart,
) async {
  final sessions = await ref
      .watch(courseRepositoryProvider)
      .getSessionsByWeek(weekStart);
  final days = List.generate(7, (_) => <CourseSessionItem>[]);
  for (final session in sessions) {
    final date = DateTime.parse(session.date);
    final day = date
        .difference(DateTime(weekStart.year, weekStart.month, weekStart.day))
        .inDays;
    if (day >= 0 && day < 7) days[day].add(session);
  }
  return CourseWeek(start: weekStart, days: days);
});

void invalidateCourseData(WidgetRef ref) {
  ref.invalidate(courseWeekProvider);
}
