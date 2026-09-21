import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/quick_note_repository.dart';
import '../domain/quick_note.dart';

final quickNoteRepositoryProvider = Provider<QuickNoteRepository>((ref) {
  return QuickNoteRepository(ref.watch(appDatabaseProvider));
});

final quickNoteSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final quickNoteTagFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final includeArchivedQuickNotesProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final quickNoteTagsProvider = FutureProvider<List<QuickNoteTagItem>>((ref) {
  return ref.watch(quickNoteRepositoryProvider).getTags();
});

final quickNotesProvider = FutureProvider.autoDispose<List<QuickNoteItem>>((
  ref,
) {
  return ref
      .watch(quickNoteRepositoryProvider)
      .getNotes(
        search: ref.watch(quickNoteSearchProvider),
        tagId: ref.watch(quickNoteTagFilterProvider),
        includeArchived: ref.watch(includeArchivedQuickNotesProvider),
      );
});

final quickNotesForDateProvider =
    FutureProvider.family<List<QuickNoteItem>, String>((ref, localDate) {
      return ref
          .watch(quickNoteRepositoryProvider)
          .getNotes(localDate: localDate);
    });

final quickNotesForMonthProvider =
    FutureProvider.family<List<QuickNoteItem>, String>((ref, localMonth) {
      return ref
          .watch(quickNoteRepositoryProvider)
          .getNotes(localMonth: localMonth);
    });

void invalidateQuickNoteData(WidgetRef ref) {
  ref.invalidate(quickNoteTagsProvider);
  ref.invalidate(quickNotesProvider);
  ref.invalidate(quickNotesForDateProvider);
  ref.invalidate(quickNotesForMonthProvider);
}
