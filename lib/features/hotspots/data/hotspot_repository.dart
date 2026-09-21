import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/hotspot.dart';

class HotspotRepository {
  HotspotRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<List<HotspotDigest>> getForDate(String localDate) async {
    final rows =
        await (_database.select(_database.dailyHotspots)
              ..where(
                (hotspot) =>
                    hotspot.localDate.equals(localDate) &
                    hotspot.deletedAt.isNull(),
              )
              ..orderBy([
                (hotspot) => OrderingTerm(expression: hotspot.category),
                (hotspot) => OrderingTerm(expression: hotspot.createdAt),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> replaceForDate({
    required String localDate,
    required List<HotspotDraft> drafts,
    required String provider,
    required String model,
  }) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await (_database.update(_database.dailyHotspots)..where(
            (hotspot) =>
                hotspot.localDate.equals(localDate) &
                hotspot.deletedAt.isNull(),
          ))
          .write(
            DailyHotspotsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      for (final draft in drafts) {
        await _database
            .into(_database.dailyHotspots)
            .insert(
              DailyHotspotsCompanion.insert(
                id: _uuid.v4(),
                localDate: localDate,
                category: draft.category.name,
                title: draft.title,
                summary: draft.summary,
                analysis: Value(
                  draft.analysis.isEmpty ? draft.summary : draft.analysis,
                ),
                keyPointsJson: jsonEncode(draft.keyPoints),
                sourcesJson: jsonEncode([
                  for (final source in draft.sources) source.toJson(),
                ]),
                confidence: Value(draft.confidence.name),
                provider: Value(provider),
                model: Value(model),
                generatedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  HotspotDigest _toDomain(DailyHotspot row) {
    final keyPoints = _decodeStringList(row.keyPointsJson);
    final sources = _decodeSources(row.sourcesJson);
    return HotspotDigest.fromRow(row, keyPoints: keyPoints, sources: sources);
  }

  List<String> _decodeStringList(String value) {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.whereType<String>().toList(growable: false)
        : const [];
  }

  List<HotspotSource> _decodeSources(String value) {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded
              .whereType<Map<String, dynamic>>()
              .map(HotspotSource.fromJson)
              .toList(growable: false)
        : const [];
  }
}
