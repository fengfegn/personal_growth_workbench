import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/calendar_event_repository.dart';
import '../domain/calendar_event.dart';

final calendarEventRepositoryProvider = Provider<CalendarEventRepository>((
  ref,
) {
  return CalendarEventRepository(ref.watch(appDatabaseProvider));
});

final calendarEventsProvider = FutureProvider<List<CalendarEventItem>>((ref) {
  return ref.watch(calendarEventRepositoryProvider).getEvents();
});

void invalidateCalendarEvents(WidgetRef ref) {
  ref.invalidate(calendarEventsProvider);
}
