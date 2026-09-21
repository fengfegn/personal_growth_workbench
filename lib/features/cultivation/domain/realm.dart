import '../../../core/database/app_database.dart' as db;

class UserRealm {
  const UserRealm({
    required this.index,
    required this.name,
    required this.requiredMental,
    required this.requiredPhysical,
    required this.description,
    required this.trialTemplate,
  });

  final int index;
  final String name;
  final int requiredMental;
  final int requiredPhysical;
  final String description;
  final RealmTrialTemplate trialTemplate;
}

class RealmTrialTemplate {
  const RealmTrialTemplate({
    required this.title,
    required this.objective,
    required this.acceptanceCriteria,
  });

  final String title;
  final String objective;
  final String acceptanceCriteria;
}

const userRealms = [
  UserRealm(
    index: 0,
    name: '闻弦',
    requiredMental: 0,
    requiredPhysical: 0,
    description: '初闻其声，开始踏上长期修炼之路。',
    trialTemplate: RealmTrialTemplate(
      title: '连续完成一周修炼',
      objective: '连续七天完成学习或锻炼修炼。',
      acceptanceCriteria: '保留七天修炼记录，并写下这一周的观察。',
    ),
  ),
  UserRealm(
    index: 1,
    name: '鸣骨',
    requiredMental: 10,
    requiredPhysical: 5,
    description: '行动开始形成节律，学习与锻炼逐渐成为习惯。',
    trialTemplate: RealmTrialTemplate(
      title: '完成第一个完整学习计划',
      objective: '制定并完成一个完整的学习计划。',
      acceptanceCriteria: '计划有目标、行动记录和完成总结。',
    ),
  ),
  UserRealm(
    index: 2,
    name: '成丹',
    requiredMental: 25,
    requiredPhysical: 10,
    description: '积累开始凝聚，已经建立稳定的成长基础。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一个可以展示的小作品',
      objective: '把学习成果转化为一个可展示的小作品。',
      acceptanceCriteria: '作品可以运行或展示，并说明自己的贡献。',
    ),
  ),
  UserRealm(
    index: 3,
    name: '点墨',
    requiredMental: 50,
    requiredPhysical: 20,
    description: '不再只是输入，开始留下属于自己的成果。',
    trialTemplate: RealmTrialTemplate(
      title: '建立明确的长期主修方向',
      objective: '明确未来一段时间的长期主修方向。',
      acceptanceCriteria: '写出方向、原因、阶段目标和下一步行动。',
    ),
  ),
  UserRealm(
    index: 4,
    name: '种莲',
    requiredMental: 90,
    requiredPhysical: 35,
    description: '找到长期主修方向，让知识开始扎根。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一个较完整的阶段项目',
      objective: '完成一个能体现阶段性成长的项目。',
      acceptanceCriteria: '项目有清晰范围、可验证成果和复盘记录。',
    ),
  ),
  UserRealm(
    index: 5,
    name: '观山',
    requiredMental: 150,
    requiredPhysical: 55,
    description: '开始看到知识体系的整体轮廓。',
    trialTemplate: RealmTrialTemplate(
      title: '独立解决一个复杂问题',
      objective: '独立完成一个需要分析、实践和验证的复杂问题。',
      acceptanceCriteria: '记录问题拆解、解决过程、结果和反思。',
    ),
  ),
  UserRealm(
    index: 6,
    name: '燃灯',
    requiredMental: 230,
    requiredPhysical: 80,
    description: '能够独立探索，在复杂问题中照亮前路。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一个中大型阶段项目',
      objective: '完成一个具有实际复杂度的中大型阶段项目。',
      acceptanceCriteria: '项目具备完整交付物、验证过程和阶段总结。',
    ),
  ),
  UserRealm(
    index: 7,
    name: '登楼',
    requiredMental: 330,
    requiredPhysical: 110,
    description: '能力从局部技巧走向完整项目与系统实践。',
    trialTemplate: RealmTrialTemplate(
      title: '建立技能路线图和长期修炼规划',
      objective: '建立自己的技能路线图与长期修炼规划。',
      acceptanceCriteria: '路线图说明当前能力、目标能力、依赖关系和节奏。',
    ),
  ),
  UserRealm(
    index: 8,
    name: '执棋',
    requiredMental: 450,
    requiredPhysical: 145,
    description: '开始主动规划技能组合与长期成长路线。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一个成熟的实用作品',
      objective: '完成一个成熟且有实际用途的作品。',
      acceptanceCriteria: '作品可被真实使用，并有持续维护或迭代记录。',
    ),
  ),
  UserRealm(
    index: 9,
    name: '落墨',
    requiredMental: 600,
    requiredPhysical: 185,
    description: '能够持续把知识转化为成熟的现实作品。',
    trialTemplate: RealmTrialTemplate(
      title: '整合多个知识或技术领域',
      objective: '将多个知识或技术领域整合进一个项目。',
      acceptanceCriteria: '说明各领域的连接方式、取舍和最终产出。',
    ),
  ),
  UserRealm(
    index: 10,
    name: '流丹',
    requiredMental: 780,
    requiredPhysical: 230,
    description: '多项能力开始融汇，并能够协同解决问题。',
    trialTemplate: RealmTrialTemplate(
      title: '总结并形成自己的方法论',
      objective: '总结长期实践，形成可复用的方法论。',
      acceptanceCriteria: '方法论有原则、步骤、适用边界和真实案例。',
    ),
  ),
  UserRealm(
    index: 11,
    name: '游虚海',
    requiredMental: 1000,
    requiredPhysical: 280,
    description: '不再依赖固定路径，逐渐形成自己的方法论。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一个跨领域大型成果',
      objective: '完成一个需要跨领域协作和综合判断的大型成果。',
      acceptanceCriteria: '成果有明确影响、完整过程和可复用经验。',
    ),
  ),
  UserRealm(
    index: 12,
    name: '万象天',
    requiredMental: 1280,
    requiredPhysical: 340,
    description: '能够跨越领域，组织复杂知识解决大型问题。',
    trialTemplate: RealmTrialTemplate(
      title: '完成代表自己的长期作品',
      objective: '完成一个真正能够代表自己的长期作品。',
      acceptanceCriteria: '作品体现长期投入、独立判断和稳定完成能力。',
    ),
  ),
  UserRealm(
    index: 13,
    name: '太上京',
    requiredMental: 1600,
    requiredPhysical: 420,
    description: '长期积累凝聚成独立体系，形成真正代表自己的成果。',
    trialTemplate: RealmTrialTemplate(
      title: '完成一部长期作品',
      objective: '继续打磨能够代表自己的长期作品。',
      acceptanceCriteria: '作品形成稳定体系，并完成公开或长期使用验证。',
    ),
  ),
];

UserRealm realmForIndex(int index) {
  return userRealms.firstWhere(
    (realm) => realm.index == index,
    orElse: () => userRealms.first,
  );
}

UserRealm? getNextRealm(int currentRealm) {
  final nextIndex = currentRealm + 1;
  if (nextIndex >= userRealms.length) return null;
  return realmForIndex(nextIndex);
}

enum RealmBottleneck { mental, physical, balanced, ready }

class RealmProgress {
  const RealmProgress({
    required this.realm,
    required this.mentalRatio,
    required this.physicalRatio,
    required this.overallRatio,
    required this.mentalRemaining,
    required this.physicalRemaining,
    required this.mentalTrainingSeconds,
    required this.physicalTrainingSeconds,
    required this.bottleneck,
  });

  final UserRealm? realm;
  final double mentalRatio;
  final double physicalRatio;
  final double overallRatio;
  final int mentalRemaining;
  final int physicalRemaining;
  final int mentalTrainingSeconds;
  final int physicalTrainingSeconds;
  final RealmBottleneck bottleneck;

  bool get ready => bottleneck == RealmBottleneck.ready;
}

RealmProgress calculateRealmProgress({
  required int currentRealm,
  required int mentalPoints,
  required int physicalPoints,
  required int mentalProgressSeconds,
  required int physicalProgressSeconds,
}) {
  final next = getNextRealm(currentRealm);
  if (next == null) {
    return const RealmProgress(
      realm: null,
      mentalRatio: 1,
      physicalRatio: 1,
      overallRatio: 1,
      mentalRemaining: 0,
      physicalRemaining: 0,
      mentalTrainingSeconds: 0,
      physicalTrainingSeconds: 0,
      bottleneck: RealmBottleneck.ready,
    );
  }
  final mentalRatio = _ratio(mentalPoints, next.requiredMental);
  final physicalRatio = _ratio(physicalPoints, next.requiredPhysical);
  final mentalRemaining = _remaining(mentalPoints, next.requiredMental);
  final physicalRemaining = _remaining(physicalPoints, next.requiredPhysical);
  final bottleneck = mentalRemaining == 0 && physicalRemaining == 0
      ? RealmBottleneck.ready
      : mentalRatio < physicalRatio
      ? RealmBottleneck.mental
      : physicalRatio < mentalRatio
      ? RealmBottleneck.physical
      : RealmBottleneck.balanced;
  return RealmProgress(
    realm: next,
    mentalRatio: mentalRatio,
    physicalRatio: physicalRatio,
    overallRatio: mentalRatio < physicalRatio ? mentalRatio : physicalRatio,
    mentalRemaining: mentalRemaining,
    physicalRemaining: physicalRemaining,
    mentalTrainingSeconds: _trainingSeconds(
      mentalRemaining,
      mentalProgressSeconds,
    ),
    physicalTrainingSeconds: _trainingSeconds(
      physicalRemaining,
      physicalProgressSeconds,
    ),
    bottleneck: bottleneck,
  );
}

bool canAttemptRealmBreakthrough({
  required int currentRealm,
  required int mentalPoints,
  required int physicalPoints,
  required bool hasActiveTrial,
}) {
  final next = getNextRealm(currentRealm);
  return next != null &&
      !hasActiveTrial &&
      mentalPoints >= next.requiredMental &&
      physicalPoints >= next.requiredPhysical;
}

double _ratio(int value, int required) {
  if (required == 0) return 1;
  final ratio = value / required;
  return ratio.clamp(0, 1).toDouble();
}

int _remaining(int value, int required) {
  final remaining = required - value;
  return remaining < 0 ? 0 : remaining;
}

int _trainingSeconds(int remainingPoints, int progressSeconds) {
  if (remainingPoints == 0) return 0;
  final seconds = remainingPoints * 3600 - progressSeconds;
  return seconds < 0 ? 0 : seconds;
}

enum RealmTrialStatus {
  notStarted('未开始'),
  inProgress('进行中'),
  pendingReview('待验收'),
  passed('已通过'),
  failed('未通过');

  const RealmTrialStatus(this.label);
  final String label;

  String get storage => name;

  static RealmTrialStatus fromStorage(String value) {
    return RealmTrialStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => RealmTrialStatus.notStarted,
    );
  }
}

class RealmTrial {
  const RealmTrial({
    required this.id,
    required this.fromRealm,
    required this.toRealm,
    required this.title,
    required this.objective,
    required this.acceptanceCriteria,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.startedAt,
    required this.submittedAt,
    required this.reviewedAt,
    required this.completedAt,
  });

  factory RealmTrial.fromRow(db.RealmTrial row) {
    return RealmTrial(
      id: row.id,
      fromRealm: row.fromRealm,
      toRealm: row.toRealm,
      title: row.title,
      objective: row.objective,
      acceptanceCriteria: row.acceptanceCriteria,
      note: row.note,
      status: RealmTrialStatus.fromStorage(row.status),
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      submittedAt: row.submittedAt,
      reviewedAt: row.reviewedAt,
      completedAt: row.completedAt,
    );
  }

  final String id;
  final int fromRealm;
  final int toRealm;
  final String title;
  final String objective;
  final String acceptanceCriteria;
  final String? note;
  final RealmTrialStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? completedAt;
}

class RealmAdvancementHistory {
  const RealmAdvancementHistory({
    required this.id,
    required this.fromRealm,
    required this.toRealm,
    required this.trialId,
    required this.mentalAtBreakthrough,
    required this.physicalAtBreakthrough,
    required this.advancedAt,
  });

  factory RealmAdvancementHistory.fromRow(db.RealmAdvancementHistory row) {
    return RealmAdvancementHistory(
      id: row.id,
      fromRealm: row.fromRealm,
      toRealm: row.toRealm,
      trialId: row.trialId,
      mentalAtBreakthrough: row.mentalAtBreakthrough,
      physicalAtBreakthrough: row.physicalAtBreakthrough,
      advancedAt: row.advancedAt,
    );
  }

  final String id;
  final int fromRealm;
  final int toRealm;
  final String trialId;
  final int mentalAtBreakthrough;
  final int physicalAtBreakthrough;
  final DateTime advancedAt;
}
