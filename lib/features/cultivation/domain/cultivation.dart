import '../../../core/database/app_database.dart' as db;

enum CultivationType {
  learning('学习'),
  exercise('锻炼');

  const CultivationType(this.label);

  final String label;

  String get storage => name;

  static CultivationType fromStorage(String value) {
    return CultivationType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CultivationType.learning,
    );
  }
}

enum TechniqueStatus {
  active('修炼中'),
  archived('已归档');

  const TechniqueStatus(this.label);

  final String label;

  String get storage => name;

  static TechniqueStatus fromStorage(String value) {
    return TechniqueStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TechniqueStatus.active,
    );
  }
}

enum ExamStatus {
  notStarted('未开始'),
  inProgress('进行中'),
  pendingReview('待验收'),
  passed('已通过'),
  failed('未通过');

  const ExamStatus(this.label);

  final String label;

  String get storage => name;

  static ExamStatus fromStorage(String value) {
    return ExamStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ExamStatus.notStarted,
    );
  }
}

class CultivationStage {
  const CultivationStage({
    required this.level,
    required this.name,
    required this.requiredProficiency,
    required this.description,
  });

  final int level;
  final String name;
  final int requiredProficiency;
  final String description;
}

const cultivationStages = [
  CultivationStage(
    level: 0,
    name: '初识',
    requiredProficiency: 0,
    description: '开始接触这门功法。',
  ),
  CultivationStage(
    level: 1,
    name: '入门',
    requiredProficiency: 10,
    description: '能够完成基础练习。',
  ),
  CultivationStage(
    level: 2,
    name: '熟练',
    requiredProficiency: 30,
    description: '能够稳定应用核心方法。',
  ),
  CultivationStage(
    level: 3,
    name: '精通',
    requiredProficiency: 60,
    description: '能够独立解决复杂问题。',
  ),
  CultivationStage(
    level: 4,
    name: '融会贯通',
    requiredProficiency: 100,
    description: '能够迁移并创造新的方法。',
  ),
];

CultivationStage stageForLevel(int level) {
  return cultivationStages.firstWhere(
    (stage) => stage.level == level,
    orElse: () => cultivationStages.last,
  );
}

CultivationStage? nextStageForLevel(int level) {
  final nextLevel = level + 1;
  if (nextLevel >= cultivationStages.length) return null;
  return cultivationStages[nextLevel];
}

class CultivationProfile {
  const CultivationProfile({
    required this.id,
    required this.currentRealm,
    required this.mentalPoints,
    required this.physicalPoints,
    required this.mentalProgressSeconds,
    required this.physicalProgressSeconds,
  });

  factory CultivationProfile.fromRow(db.CultivationProfile row) {
    return CultivationProfile(
      id: row.id,
      currentRealm: row.currentRealm,
      mentalPoints: row.mentalPoints,
      physicalPoints: row.physicalPoints,
      mentalProgressSeconds: row.mentalProgressSeconds,
      physicalProgressSeconds: row.physicalProgressSeconds,
    );
  }

  final String id;
  final int currentRealm;
  final int mentalPoints;
  final int physicalPoints;
  final int mentalProgressSeconds;
  final int physicalProgressSeconds;
}

class Technique {
  const Technique({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.level,
    required this.proficiency,
    required this.proficiencyProgressSeconds,
    required this.totalSeconds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Technique.fromRow(db.Technique row) {
    return Technique(
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      level: row.level,
      proficiency: row.proficiency,
      proficiencyProgressSeconds: row.proficiencyProgressSeconds,
      totalSeconds: row.totalSeconds,
      status: TechniqueStatus.fromStorage(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? category;
  final int level;
  final int proficiency;
  final int proficiencyProgressSeconds;
  final int totalSeconds;
  final TechniqueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  CultivationStage get stage => stageForLevel(level);
  CultivationStage? get nextStage => nextStageForLevel(level);
  bool get isMaxLevel => nextStage == null;

  int get nextStageProgress => nextStage?.requiredProficiency ?? proficiency;

  bool canAdvance({bool hasActiveExam = false}) {
    final next = nextStage;
    return next != null &&
        proficiency >= next.requiredProficiency &&
        !hasActiveExam;
  }
}

class CultivationSession {
  const CultivationSession({
    required this.id,
    required this.type,
    required this.techniqueId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.mentalGained,
    required this.physicalGained,
    required this.proficiencyGained,
    required this.note,
    required this.settled,
    required this.createdAt,
  });

  factory CultivationSession.fromRow(db.CultivationSession row) {
    return CultivationSession(
      id: row.id,
      type: CultivationType.fromStorage(row.type),
      techniqueId: row.techniqueId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      durationSeconds: row.durationSeconds,
      mentalGained: row.mentalGained,
      physicalGained: row.physicalGained,
      proficiencyGained: row.proficiencyGained,
      note: row.note,
      settled: row.settled,
      createdAt: row.createdAt,
    );
  }

  final String id;
  final CultivationType type;
  final String? techniqueId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int mentalGained;
  final int physicalGained;
  final int proficiencyGained;
  final String? note;
  final bool settled;
  final DateTime createdAt;
}

class AdvancementExam {
  const AdvancementExam({
    required this.id,
    required this.techniqueId,
    required this.fromLevel,
    required this.toLevel,
    required this.title,
    required this.objective,
    required this.acceptanceCriteria,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.submittedAt,
    required this.reviewedAt,
  });

  factory AdvancementExam.fromRow(db.AdvancementExam row) {
    return AdvancementExam(
      id: row.id,
      techniqueId: row.techniqueId,
      fromLevel: row.fromLevel,
      toLevel: row.toLevel,
      title: row.title,
      objective: row.objective,
      acceptanceCriteria: row.acceptanceCriteria,
      note: row.note,
      status: ExamStatus.fromStorage(row.status),
      createdAt: row.createdAt,
      submittedAt: row.submittedAt,
      reviewedAt: row.reviewedAt,
    );
  }

  final String id;
  final String techniqueId;
  final int fromLevel;
  final int toLevel;
  final String title;
  final String objective;
  final String acceptanceCriteria;
  final String? note;
  final ExamStatus status;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
}

class AdvancementHistory {
  const AdvancementHistory({
    required this.id,
    required this.techniqueId,
    required this.fromLevel,
    required this.toLevel,
    required this.examId,
    required this.advancedAt,
  });

  factory AdvancementHistory.fromRow(db.AdvancementHistory row) {
    return AdvancementHistory(
      id: row.id,
      techniqueId: row.techniqueId,
      fromLevel: row.fromLevel,
      toLevel: row.toLevel,
      examId: row.examId,
      advancedAt: row.advancedAt,
    );
  }

  final String id;
  final String techniqueId;
  final int fromLevel;
  final int toLevel;
  final String examId;
  final DateTime advancedAt;
}
