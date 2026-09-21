import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/database/app_database.dart';
import 'package:personal_growth_workbench/core/database/database_provider.dart';
import 'package:personal_growth_workbench/features/hotspots/presentation/hotspot_page.dart';

void main() {
  testWidgets(
    'opens with local cache state and does not require a source request',
    (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: HotspotPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI News Briefs'), findsOneWidget);
      expect(find.text('No cached briefs for today.'), findsOneWidget);
      expect(find.text('Update briefs'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    },
  );
}
