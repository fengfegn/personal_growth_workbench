import 'cultivation.dart';

class SettlementResult {
  const SettlementResult({
    required this.mentalPoints,
    required this.physicalPoints,
    required this.proficiency,
    required this.mentalProgressSeconds,
    required this.physicalProgressSeconds,
    required this.proficiencyProgressSeconds,
  });

  final int mentalPoints;
  final int physicalPoints;
  final int proficiency;
  final int mentalProgressSeconds;
  final int physicalProgressSeconds;
  final int proficiencyProgressSeconds;
}

SettlementResult settleCultivationSession({
  required CultivationType type,
  required int durationSeconds,
  required int mentalProgressSeconds,
  required int physicalProgressSeconds,
  int proficiency = 0,
  int proficiencyProgressSeconds = 0,
  String? techniqueId,
}) {
  final seconds = durationSeconds < 0 ? 0 : durationSeconds;
  var mentalPoints = 0;
  var physicalPoints = 0;
  var nextMentalProgress = mentalProgressSeconds;
  var nextPhysicalProgress = physicalProgressSeconds;
  var nextProficiency = proficiency;
  var nextProficiencyProgress = proficiencyProgressSeconds;

  if (type == CultivationType.learning) {
    nextMentalProgress += seconds;
    mentalPoints = nextMentalProgress ~/ 3600;
    nextMentalProgress %= 3600;
    if (techniqueId != null) {
      nextProficiencyProgress += seconds;
      final gained = nextProficiencyProgress ~/ 3600;
      nextProficiency += gained;
      nextProficiencyProgress %= 3600;
    }
  } else {
    nextPhysicalProgress += seconds;
    physicalPoints = nextPhysicalProgress ~/ 3600;
    nextPhysicalProgress %= 3600;
  }

  return SettlementResult(
    mentalPoints: mentalPoints,
    physicalPoints: physicalPoints,
    proficiency: nextProficiency,
    mentalProgressSeconds: nextMentalProgress,
    physicalProgressSeconds: nextPhysicalProgress,
    proficiencyProgressSeconds: nextProficiencyProgress,
  );
}

String formatDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remaining = safeSeconds % 60;
  return hours > 0
      ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
      : '${minutes}m ${remaining.toString().padLeft(2, '0')}s';
}

String formatClock(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remaining = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}
