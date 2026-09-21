import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../application/cultivation_providers.dart';
import '../domain/cultivation.dart';
import '../domain/cultivation_settlement.dart';
import '../domain/realm.dart';

const _windowChannel = MethodChannel('personal_growth_workbench/window');

Future<void> _invokeWindowMethod(String method, Object? arguments) async {
  try {
    await _windowChannel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    // Window controls are only available on supported desktop runners.
  } on PlatformException {
    // Keep the timer usable when a platform does not expose window controls.
  }
}

class CultivationPage extends ConsumerStatefulWidget {
  const CultivationPage({super.key});

  @override
  ConsumerState<CultivationPage> createState() => _CultivationPageState();
}

class _CultivationPageState extends ConsumerState<CultivationPage> {
  _RunningCultivation? _running;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _timerFullscreen = false;
  bool _isFinishing = false;
  Future<void>? _fullscreenDialogFuture;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(cultivationDashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('图灵修炼'),
        actions: [
          if (_running != null && _timerFullscreen)
            IconButton(
              tooltip: '退出全屏计时',
              onPressed: _toggleTimerFullscreen,
              icon: const Icon(Icons.fullscreen_exit),
            ),
          IconButton(
            tooltip: '创建功法',
            onPressed: () => _showTechniqueEditor(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取修炼数据失败：$error')),
        data: (dashboard) => _buildBody(context, dashboard),
      ),
      floatingActionButton: _running == null
          ? FloatingActionButton.extended(
              onPressed: () => _startCultivation(context),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('开始修炼'),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, CultivationDashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 108),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageIntro(onStart: () => _startCultivation(context)),
                    const SizedBox(height: 20),
                    if (_running != null) ...[
                      _RunningCard(
                        running: _running!,
                        elapsedSeconds: _elapsedSeconds,
                        onPause: _togglePause,
                        onFinish: _finishCultivation,
                        onToggleFullscreen: _toggleTimerFullscreen,
                        isFullscreen: false,
                      ),
                      const SizedBox(height: 20),
                    ],
                    _ResponsivePair(
                      isWide: isWide,
                      primary: _RealmCard(
                        data: data,
                        onOpen: () => context.push('/cultivation/realm'),
                        onStartTrial: () =>
                            _showRealmTrialEditor(context, data),
                      ),
                      secondary: _TodayCard(data: data),
                    ),
                    const SizedBox(height: 20),
                    _CultivationHistoryCard(
                      summaries: data.recentDailySummaries,
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: '我的功法',
                      subtitle: '记录每一项技能的修炼进度',
                      action: IconButton.filledTonal(
                        tooltip: '创建功法',
                        onPressed: () => _showTechniqueEditor(context),
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (data.techniques.isEmpty)
                      _EmptyTechniques(
                        onCreate: () => _showTechniqueEditor(context),
                      )
                    else
                      _TechniqueGrid(
                        techniques: data.techniques,
                        data: data,
                        isWide: isWide,
                        onOpen: (technique) => context.push(
                          '/cultivation/technique/${technique.id}',
                        ),
                        onStart: (technique) =>
                            _startCultivation(context, technique: technique),
                        onEdit: (technique) =>
                            _showTechniqueEditor(context, technique: technique),
                        onArchive: _archiveTechnique,
                        onAdvance: (technique) =>
                            _showExamEditor(context, technique),
                      ),
                    if (data.activeRealmTrial != null ||
                        data.activeExams.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _SectionTitle(title: '进行中的事项', subtitle: '把阶段成果推进到验收'),
                      const SizedBox(height: 12),
                      if (data.activeRealmTrial != null &&
                          data.activeExams.isNotEmpty)
                        _ResponsivePair(
                          isWide: isWide,
                          primary: _buildRealmTrialCard(data),
                          secondary: _buildExamCards(data),
                        )
                      else if (data.activeRealmTrial != null)
                        _buildRealmTrialCard(data)
                      else
                        _buildExamCards(data),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRealmTrialCard(CultivationDashboardData data) {
    final trial = data.activeRealmTrial!;
    return _RealmTrialCard(
      trial: trial,
      fromRealm: realmForIndex(trial.fromRealm),
      toRealm: realmForIndex(trial.toRealm),
      onStatusChanged: (status) => _changeRealmTrialStatus(trial, status),
      onPass: () => _passRealmTrial(trial),
      onFail: () => _failRealmTrial(trial),
    );
  }

  Widget _buildExamCards(CultivationDashboardData data) {
    return Column(
      children: [
        for (final exam in data.activeExams)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExamCard(
              exam: exam,
              technique: data.techniques
                  .where((item) => item.id == exam.techniqueId)
                  .firstOrNull,
              onStatusChanged: (status) => _changeExamStatus(exam, status),
              onPass: () => _passExam(exam),
              onFail: () => _failExam(exam),
            ),
          ),
      ],
    );
  }

  Future<void> _startCultivation(
    BuildContext context, {
    Technique? technique,
  }) async {
    final values = await showDialog<_CultivationStartValues>(
      context: context,
      builder: (context) => _CultivationStartDialog(
        techniques:
            ref.read(cultivationDashboardProvider).valueOrNull?.techniques ??
            const [],
        initialTechnique: technique,
      ),
    );
    if (values == null) return;
    setState(() {
      _running = _RunningCultivation(
        type: values.type,
        technique: values.technique,
        note: values.note,
        startedAt: DateTime.now().toUtc(),
        targetSeconds: values.countdownMinutes == null
            ? null
            : values.countdownMinutes! * 60,
      );
      _elapsedSeconds = 0;
      _isFinishing = false;
    });
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCultivation(),
    );
    if (values.fullscreen) {
      unawaited(_enterTimerFullscreen());
    }
  }

  void _tickCultivation() {
    final running = _running;
    if (!mounted || running == null || _isFinishing) return;
    final now = DateTime.now().toUtc();
    final elapsed = running.effectiveSeconds(now);
    setState(() => _elapsedSeconds = elapsed);
    final target = running.targetSeconds;
    if (target != null && elapsed >= target) {
      _isFinishing = true;
      unawaited(_finishCultivation(autoCompleted: true));
    }
  }

  void _togglePause() {
    final running = _running;
    if (running == null) return;
    setState(() {
      if (running.pausedAt == null) {
        running.pausedAt = DateTime.now().toUtc();
      } else {
        running.pausedSeconds += DateTime.now()
            .toUtc()
            .difference(running.pausedAt!)
            .inSeconds;
        running.pausedAt = null;
      }
      _elapsedSeconds = running.effectiveSeconds(DateTime.now().toUtc());
    });
  }

  Future<void> _finishCultivation({bool autoCompleted = false}) async {
    final running = _running;
    if (running == null || _isFinishing && !autoCompleted) return;
    _isFinishing = true;
    final endedAt = DateTime.now().toUtc();
    final elapsed = running.effectiveSeconds(endedAt);
    final duration = running.targetSeconds == null
        ? elapsed
        : elapsed.clamp(0, running.targetSeconds!).toInt();
    _ticker?.cancel();
    try {
      final session = await ref
          .read(cultivationRepositoryProvider)
          .finishSession(
            id: running.id,
            type: running.type,
            techniqueId: running.technique?.id,
            startedAt: running.startedAt,
            endedAt: endedAt,
            durationSeconds: duration,
            note: running.note,
          );
      if (!mounted) return;
      final fullscreenFuture = _fullscreenDialogFuture;
      if (_timerFullscreen) {
        Navigator.of(context, rootNavigator: true).pop();
        if (fullscreenFuture != null) await fullscreenFuture;
      }
      setState(() {
        _running = null;
        _timerFullscreen = false;
      });
      await _invokeWindowMethod('setFullscreen', false);
      invalidateCultivationData(ref);
      if (autoCompleted) {
        await _showCompletionDialog(session);
      } else {
        if (mounted) _showMessage(context, _sessionSummary(session));
      }
    } catch (error) {
      _isFinishing = false;
      if (mounted) _showMessage(context, '修炼未能保存：$error');
    }
  }

  Future<void> _toggleTimerFullscreen() async {
    if (_timerFullscreen) {
      _exitTimerFullscreen();
    } else {
      await _enterTimerFullscreen();
    }
  }

  Future<void> _enterTimerFullscreen() async {
    final running = _running;
    if (running == null || _timerFullscreen) return;
    setState(() => _timerFullscreen = true);
    await _invokeWindowMethod('setFullscreen', true);
    if (!mounted || !_timerFullscreen || _running == null) return;

    final future = showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullscreenTimerView(
          running: running,
          onExit: _exitTimerFullscreen,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
    _fullscreenDialogFuture = future;
    await future;
    if (identical(_fullscreenDialogFuture, future)) {
      _fullscreenDialogFuture = null;
    }
    if (mounted) setState(() => _timerFullscreen = false);
    await _invokeWindowMethod('setFullscreen', false);
  }

  void _exitTimerFullscreen() {
    if (!_timerFullscreen) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _showCompletionDialog(CultivationSession session) async {
    await _invokeWindowMethod('bringToFront', true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CultivationCompletionDialog(session: session),
    );
    await _invokeWindowMethod('bringToFront', false);
  }

  String _sessionSummary(CultivationSession session) {
    final rewards = <String>[];
    if (session.mentalGained > 0) {
      rewards.add('精神 +${session.mentalGained}');
    }
    if (session.physicalGained > 0) {
      rewards.add('体质 +${session.physicalGained}');
    }
    if (session.proficiencyGained > 0) {
      rewards.add('功法熟练度 +${session.proficiencyGained}');
    }
    return rewards.isEmpty
        ? '修炼已保存，本次累计 ${formatDuration(session.durationSeconds)}'
        : '修炼完成：${rewards.join('，')}';
  }

  Future<void> _showTechniqueEditor(
    BuildContext context, {
    Technique? technique,
  }) async {
    final values = await showDialog<_TechniqueFormValues>(
      context: context,
      builder: (context) => _TechniqueEditorDialog(technique: technique),
    );
    if (values == null) return;
    try {
      final repository = ref.read(cultivationRepositoryProvider);
      if (technique == null) {
        await repository.createTechnique(
          name: values.name,
          description: values.description,
          category: values.category,
        );
      } else {
        await repository.updateTechnique(
          id: technique.id,
          name: values.name,
          description: values.description,
          category: values.category,
        );
      }
      invalidateCultivationData(ref);
    } catch (error) {
      if (context.mounted) _showMessage(context, '功法保存失败：$error');
    }
  }

  Future<void> _archiveTechnique(Technique technique) async {
    await ref
        .read(cultivationRepositoryProvider)
        .archiveTechnique(technique.id);
    invalidateCultivationData(ref);
  }

  Future<void> _showExamEditor(
    BuildContext context,
    Technique technique,
  ) async {
    final values = await showDialog<_ExamFormValues>(
      context: context,
      builder: (context) => _ExamEditorDialog(technique: technique),
    );
    if (values == null) return;
    try {
      await ref
          .read(cultivationRepositoryProvider)
          .createExam(
            techniqueId: technique.id,
            title: values.title,
            objective: values.objective,
            acceptanceCriteria: values.acceptanceCriteria,
            note: values.note,
          );
      invalidateCultivationData(ref);
      if (context.mounted) _showMessage(context, '阶段考核已创建');
    } catch (error) {
      if (context.mounted) _showMessage(context, '考核创建失败：$error');
    }
  }

  Future<void> _showRealmTrialEditor(
    BuildContext context,
    CultivationDashboardData data,
  ) async {
    final next = data.realmProgress.realm;
    if (next == null) return;
    final values = await showDialog<_RealmTrialFormValues>(
      context: context,
      builder: (context) => _RealmTrialEditorDialog(next: next),
    );
    if (values == null) return;
    try {
      await ref
          .read(cultivationRepositoryProvider)
          .createRealmTrial(
            title: values.title,
            objective: values.objective,
            acceptanceCriteria: values.acceptanceCriteria,
            note: values.note,
          );
      invalidateCultivationData(ref);
      if (context.mounted) _showMessage(context, '突破试炼已创建');
    } catch (error) {
      if (context.mounted) _showMessage(context, '突破试炼创建失败：$error');
    }
  }

  Future<void> _changeRealmTrialStatus(
    RealmTrial trial,
    RealmTrialStatus status,
  ) async {
    await ref
        .read(cultivationRepositoryProvider)
        .setRealmTrialStatus(trial.id, status);
    invalidateCultivationData(ref);
  }

  Future<void> _passRealmTrial(RealmTrial trial) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认通过突破验收？'),
        content: Text(
          '确认本次试炼已经达到验收标准。通过后将完成\n${realmForIndex(trial.fromRealm).name} → ${realmForIndex(trial.toRealm).name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认通过'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(cultivationRepositoryProvider).passRealmTrial(trial.id);
      invalidateCultivationData(ref);
      if (mounted) _showMessage(context, '境界突破成功');
    } catch (error) {
      if (mounted) _showMessage(context, '境界突破失败：$error');
    }
  }

  Future<void> _failRealmTrial(RealmTrial trial) async {
    await ref.read(cultivationRepositoryProvider).failRealmTrial(trial.id);
    invalidateCultivationData(ref);
    if (mounted) _showMessage(context, '试炼已记录为未通过，可重新创建');
  }

  Future<void> _changeExamStatus(
    AdvancementExam exam,
    ExamStatus status,
  ) async {
    await ref
        .read(cultivationRepositoryProvider)
        .setExamStatus(exam.id, status);
    invalidateCultivationData(ref);
  }

  Future<void> _passExam(AdvancementExam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认通过验收？'),
        content: const Text('确认该阶段成果已达到验收标准。通过后将晋升到下一境界。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认通过'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(cultivationRepositoryProvider).passExam(exam.id);
      invalidateCultivationData(ref);
      if (mounted) _showMessage(context, '进阶成功');
    } catch (error) {
      if (mounted) _showMessage(context, '进阶失败：$error');
    }
  }

  Future<void> _failExam(AdvancementExam exam) async {
    await ref.read(cultivationRepositoryProvider).failExam(exam.id);
    invalidateCultivationData(ref);
    if (mounted) _showMessage(context, '考核已记录为未通过，可重新发起考核');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RunningCultivation {
  _RunningCultivation({
    required this.type,
    required this.technique,
    required this.note,
    required this.startedAt,
    this.targetSeconds,
  }) : id = UniqueKey().toString();

  final String id;
  final CultivationType type;
  final Technique? technique;
  final String? note;
  final DateTime startedAt;
  final int? targetSeconds;
  DateTime? pausedAt;
  int pausedSeconds = 0;

  bool get isCountdown => targetSeconds != null;

  int effectiveSeconds(DateTime now) {
    final pause = pausedAt == null
        ? pausedSeconds
        : pausedSeconds + now.difference(pausedAt!).inSeconds;
    final value = now.difference(startedAt).inSeconds - pause;
    return value < 0 ? 0 : value;
  }

  int displaySeconds(int elapsedSeconds) {
    final target = targetSeconds;
    if (target == null) return elapsedSeconds;
    final remaining = target - elapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            subtitle!,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
      const Spacer(),
      ?action,
    ],
  );
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '图灵修炼',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '以时间为炉，以项目为证。',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.timer_outlined),
          label: const Text('开始修炼'),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.isWide,
    required this.primary,
    required this.secondary,
  });

  final bool isWide;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 12), secondary],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: primary),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: secondary),
      ],
    );
  }
}

class _TechniqueGrid extends StatelessWidget {
  const _TechniqueGrid({
    required this.techniques,
    required this.data,
    required this.isWide,
    required this.onOpen,
    required this.onStart,
    required this.onEdit,
    required this.onArchive,
    required this.onAdvance,
  });

  final List<Technique> techniques;
  final CultivationDashboardData data;
  final bool isWide;
  final ValueChanged<Technique> onOpen;
  final ValueChanged<Technique> onStart;
  final ValueChanged<Technique> onEdit;
  final ValueChanged<Technique> onArchive;
  final ValueChanged<Technique> onAdvance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isWide && constraints.maxWidth >= 760 ? 2 : 1;
        final gap = 12.0;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final technique in techniques)
              SizedBox(
                width: cardWidth,
                child: _TechniqueCard(
                  technique: technique,
                  exam: data.examFor(technique.id),
                  onOpen: () => onOpen(technique),
                  onStart: () => onStart(technique),
                  onEdit: () => onEdit(technique),
                  onArchive: () => onArchive(technique),
                  onAdvance: () => onAdvance(technique),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data});
  final CultivationDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mental = data.recentSessions.fold(
      0,
      (sum, item) => sum + item.mentalGained,
    );
    final physical = data.recentSessions.fold(
      0,
      (sum, item) => sum + item.physicalGained,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeading(
              icon: Icons.today_outlined,
              title: '今日修炼',
              trailing: Text(
                '持续积累',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '学习',
                    value: formatDuration(data.todayLearningSeconds),
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '锻炼',
                    value: formatDuration(data.todayExerciseSeconds),
                    icon: Icons.fitness_center_outlined,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _CompactMetric(label: '精神成长', value: '+$mental'),
                ),
                Expanded(
                  child: _CompactMetric(label: '体质成长', value: '+$physical'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CultivationHistoryCard extends StatelessWidget {
  const _CultivationHistoryCard({required this.summaries});

  final List<DailyCultivationSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final learningColor = colors.primary;
    final exerciseColor = colors.secondary;
    final learningSeconds = summaries.fold(
      0,
      (total, item) => total + item.learningSeconds,
    );
    final exerciseSeconds = summaries.fold(
      0,
      (total, item) => total + item.exerciseSeconds,
    );

    return Semantics(
      container: true,
      label:
          '近7日修炼，学习${formatDuration(learningSeconds)}，锻炼${formatDuration(exerciseSeconds)}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeading(
                icon: Icons.bar_chart_outlined,
                title: '近 7 日修炼',
                trailing: Text(
                  '按天统计',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _ChartLegend(color: learningColor, label: '学习 1h'),
                  _ChartLegend(color: exerciseColor, label: '锻炼 20min'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '同等柱高：学习 1 小时 = 锻炼 20 分钟',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 218,
                child: _DailyCultivationBarChart(
                  summaries: summaries,
                  learningColor: learningColor,
                  exerciseColor: exerciseColor,
                  textStyle: theme.textTheme.bodySmall,
                  labelColor: colors.onSurfaceVariant,
                  gridColor: colors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DailyCultivationBarChart extends StatelessWidget {
  const _DailyCultivationBarChart({
    required this.summaries,
    required this.learningColor,
    required this.exerciseColor,
    required this.textStyle,
    required this.labelColor,
    required this.gridColor,
  });

  final List<DailyCultivationSummary> summaries;
  final Color learningColor;
  final Color exerciseColor;
  final TextStyle? textStyle;
  final Color labelColor;
  final Color gridColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = DailyChartLayout.fromSize(size, summaries);
        return Stack(
          children: [
            CustomPaint(
              key: const ValueKey('cultivation-daily-chart'),
              painter: _DailyCultivationBarChartPainter(
                summaries: summaries,
                learningColor: learningColor,
                exerciseColor: exerciseColor,
                textStyle: textStyle,
                labelColor: labelColor,
                gridColor: gridColor,
              ),
              child: const SizedBox.expand(),
            ),
            for (var index = 0; index < summaries.length; index++)
              for (final learning in [true, false])
                _buildTooltipTarget(
                  layout,
                  summaries[index],
                  index,
                  learning: learning,
                  size: size,
                ),
          ],
        );
      },
    );
  }

  Widget _buildTooltipTarget(
    DailyChartLayout layout,
    DailyCultivationSummary summary,
    int index, {
    required bool learning,
    required Size size,
  }) {
    final seconds = learning
        ? summary.learningSeconds
        : summary.exerciseSeconds;
    if (seconds <= 0) return const SizedBox.shrink();
    final bar = layout.barRect(summary, index, learning: learning);
    final hitHeight = math.max(20.0, bar.height + 8);
    final top = math.max(0.0, bar.bottom - hitHeight);
    final target = Rect.fromLTWH(
      bar.left,
      top,
      bar.width,
      math.min(hitHeight, size.height - top),
    );
    return Positioned.fromRect(
      rect: target,
      child: Tooltip(
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 180),
        message:
            '${learning ? '学习时长' : '锻炼时长'}：${_formatTooltipDuration(seconds)}',
        child: const SizedBox.expand(),
      ),
    );
  }
}

class DailyChartLayout {
  const DailyChartLayout({
    required this.chart,
    required this.groupWidth,
    required this.barWidth,
    required this.gap,
    required this.axisMaxUnits,
  });

  final Rect chart;
  final double groupWidth;
  final double barWidth;
  final double gap;
  final int axisMaxUnits;

  factory DailyChartLayout.fromSize(
    Size size,
    List<DailyCultivationSummary> summaries,
  ) {
    const leftAxisWidth = 70.0;
    const topPadding = 10.0;
    const bottomAxisHeight = 26.0;
    final chart = Rect.fromLTWH(
      leftAxisWidth,
      topPadding,
      math.max(0, size.width - leftAxisWidth - 4),
      math.max(0, size.height - topPadding - bottomAxisHeight),
    );
    final groupWidth = summaries.isEmpty ? 0.0 : chart.width / summaries.length;
    return DailyChartLayout(
      chart: chart,
      groupWidth: groupWidth,
      barWidth: math.min(18.0, groupWidth * 0.27),
      gap: math.min(5.0, groupWidth * 0.08),
      axisMaxUnits: _axisMaximumUnits(summaries),
    );
  }

  Rect barRect(
    DailyCultivationSummary summary,
    int index, {
    required bool learning,
  }) {
    final seconds = learning
        ? summary.learningSeconds
        : summary.exerciseSeconds;
    if (seconds <= 0) return Rect.zero;
    final units = learning ? seconds / 3600 : seconds / 1200;
    final height = chart.height * units / axisMaxUnits;
    final centerX = barGroupCenterX(index);
    final hasLearning = summary.learningSeconds > 0;
    final hasExercise = summary.exerciseSeconds > 0;
    final isSingleBar = hasLearning != hasExercise;
    final left = isSingleBar
        ? centerX - barWidth / 2
        : learning
        ? centerX - gap / 2 - barWidth
        : centerX + gap / 2;
    return Rect.fromLTWH(
      left,
      chart.bottom - math.max(2.0, height),
      barWidth,
      math.max(2.0, height),
    );
  }

  double categoryCenterX(int index) => chart.left + groupWidth * (index + 0.5);

  double tickCenterX(int index) => categoryCenterX(index);

  double barGroupCenterX(int index) => categoryCenterX(index);
}

class _DailyCultivationBarChartPainter extends CustomPainter {
  _DailyCultivationBarChartPainter({
    required this.summaries,
    required this.learningColor,
    required this.exerciseColor,
    required this.textStyle,
    required this.labelColor,
    required this.gridColor,
  });

  final List<DailyCultivationSummary> summaries;
  final Color learningColor;
  final Color exerciseColor;
  final TextStyle? textStyle;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (summaries.isEmpty || size.width <= 0 || size.height <= 0) return;
    final layout = DailyChartLayout.fromSize(size, summaries);
    final chart = layout.chart;
    if (chart.width <= 0 || chart.height <= 0) return;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final fraction = index / 4;
      final y = chart.bottom - chart.height * fraction;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawAxisLabel(
        canvas,
        layout.axisMaxUnits * fraction,
        Offset(0, y - 7),
        width: chart.left - 8,
      );
    }

    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];
      final centerX = layout.tickCenterX(index);
      _drawDateTick(
        canvas,
        '${summary.date.month}/${summary.date.day}',
        centerX,
        chart.bottom + 9,
      );
      _drawBar(
        canvas,
        layout.barRect(summary, index, learning: true),
        learningColor,
      );
      _drawBar(
        canvas,
        layout.barRect(summary, index, learning: false),
        exerciseColor,
      );
    }
  }

  void _drawBar(Canvas canvas, Rect rect, Color color) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final radius = Radius.circular(math.min(4, rect.width / 2));
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
      Paint()..color = color,
    );
  }

  void _drawAxisLabel(
    Canvas canvas,
    double units,
    Offset offset, {
    required double width,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: _formatLearningUnits(units),
            style: textStyle?.copyWith(color: learningColor, fontSize: 11),
          ),
          TextSpan(
            text: ' / ',
            style: textStyle?.copyWith(color: labelColor, fontSize: 11),
          ),
          TextSpan(
            text: _formatExerciseUnits(units),
            style: textStyle?.copyWith(color: exerciseColor, fontSize: 11),
          ),
        ],
      ),
      textAlign: TextAlign.right,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  void _drawDateTick(Canvas canvas, String text, double centerX, double top) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle?.copyWith(color: labelColor, fontSize: 11),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
  }

  @override
  bool shouldRepaint(_DailyCultivationBarChartPainter oldDelegate) {
    return oldDelegate.summaries != summaries ||
        oldDelegate.learningColor != learningColor ||
        oldDelegate.exerciseColor != exerciseColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textStyle != textStyle;
  }
}

int _axisMaximumUnits(List<DailyCultivationSummary> summaries) {
  final maxUnits = summaries.fold<double>(0, (max, summary) {
    final learningUnits = summary.learningSeconds / 3600;
    final exerciseUnits = summary.exerciseSeconds / 1200;
    return math.max(max, math.max(learningUnits, exerciseUnits));
  });
  final rounded = ((maxUnits.ceil() + 3) ~/ 4) * 4;
  return math.max(4, rounded);
}

String _formatLearningUnits(double units) {
  return '${units.round()}h';
}

String _formatExerciseUnits(double units) {
  return '${(units * 20).round()}m';
}

String _formatTooltipDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours > 0 && remainingMinutes > 0) {
    return '$hours小时$remainingMinutes分钟';
  }
  if (hours > 0) return '$hours小时';
  if (minutes > 0) return '$minutes分钟';
  return '$seconds秒';
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RealmCard extends StatelessWidget {
  const _RealmCard({
    required this.data,
    required this.onOpen,
    required this.onStartTrial,
  });

  final CultivationDashboardData data;
  final VoidCallback onOpen;
  final VoidCallback onStartTrial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = data.realmProgress;
    final next = progress.realm;
    final isMax = next == null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeading(
                icon: Icons.auto_awesome_outlined,
                title: '当前境界',
                trailing: Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.currentRealm.name,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.currentRealm.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.self_improvement_outlined,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isMax)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '当前版本最高境界',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      '下一境界：${next.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress.overallRatio * 100).round()}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress.overallRatio,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _RealmAttributeProgress(
                        label: '精神',
                        current: data.profile.mentalPoints,
                        requiredValue: next.requiredMental,
                        ratio: progress.mentalRatio,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RealmAttributeProgress(
                        label: '体质',
                        current: data.profile.physicalPoints,
                        requiredValue: next.requiredPhysical,
                        ratio: progress.physicalRatio,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      progress.ready
                          ? Icons.check_circle_outline
                          : Icons.track_changes_outlined,
                      size: 18,
                      color: progress.ready
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      progress.ready
                          ? '数值条件已满足'
                          : '当前瓶颈：${_bottleneckLabel(progress.bottleneck)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  progress.ready
                      ? '可以开始准备突破试炼'
                      : '距离突破：精神 +${progress.mentalRemaining} · 体质 +${progress.physicalRemaining}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (data.canAttemptRealmBreakthrough)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: onStartTrial,
                        icon: const Icon(Icons.trending_up),
                        label: const Text('开始突破'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _bottleneckLabel(RealmBottleneck bottleneck) {
    switch (bottleneck) {
      case RealmBottleneck.mental:
        return '精神';
      case RealmBottleneck.physical:
        return '体质';
      case RealmBottleneck.balanced:
        return '精神与体质';
      case RealmBottleneck.ready:
        return '已满足';
    }
  }
}

class _RealmAttributeProgress extends StatelessWidget {
  const _RealmAttributeProgress({
    required this.label,
    required this.current,
    required this.requiredValue,
    required this.ratio,
  });

  final String label;
  final int current;
  final int requiredValue;
  final double ratio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            label == '精神'
                ? Icons.psychology_outlined
                : Icons.fitness_center_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          Text(
            '${(ratio * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Text(
        '$current / $requiredValue',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(minHeight: 7, value: ratio),
      ),
    ],
  );
}

class _RealmTrialCard extends StatelessWidget {
  const _RealmTrialCard({
    required this.trial,
    required this.fromRealm,
    required this.toRealm,
    required this.onStatusChanged,
    required this.onPass,
    required this.onFail,
  });

  final RealmTrial trial;
  final UserRealm fromRealm;
  final UserRealm toRealm;
  final ValueChanged<RealmTrialStatus> onStatusChanged;
  final VoidCallback onPass;
  final VoidCallback onFail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeading(
              icon: Icons.flag_outlined,
              title: '当前突破试炼',
              trailing: _StatusPill(label: trial.status.label),
            ),
            const SizedBox(height: 16),
            Text(
              '${fromRealm.name} → ${toRealm.name}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(trial.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              trial.objective,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              '验收标准',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(trial.acceptanceCriteria),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (trial.status == RealmTrialStatus.notStarted)
                  OutlinedButton(
                    onPressed: () =>
                        onStatusChanged(RealmTrialStatus.inProgress),
                    child: const Text('开始试炼'),
                  ),
                if (trial.status == RealmTrialStatus.inProgress)
                  OutlinedButton(
                    onPressed: () =>
                        onStatusChanged(RealmTrialStatus.pendingReview),
                    child: const Text('提交验收'),
                  ),
                if (trial.status == RealmTrialStatus.pendingReview) ...[
                  FilledButton.icon(
                    onPressed: onPass,
                    icon: const Icon(Icons.check),
                    label: const Text('通过验收'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onFail,
                    icon: const Icon(Icons.close),
                    label: const Text('未通过'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({
    required this.technique,
    required this.exam,
    required this.onOpen,
    required this.onStart,
    required this.onEdit,
    required this.onArchive,
    required this.onAdvance,
  });
  final Technique technique;
  final AdvancementExam? exam;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final next = technique.nextStage;
    final canAdvance = technique.canAdvance(hasActiveExam: exam != null);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      technique.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'archive') onArchive();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'archive', child: Text('归档')),
                    ],
                  ),
                ],
              ),
              if (technique.category?.isNotEmpty == true)
                Text(
                  technique.category!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '境界：${technique.stage.name}${next == null ? '' : ' · 下一阶段 ${next.name}'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                minHeight: 7,
                value: next == null
                    ? 1
                    : (technique.proficiency / next.requiredProficiency).clamp(
                        0,
                        1,
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                '熟练度 ${technique.proficiency} / ${next?.requiredProficiency ?? technique.proficiency} · 累计 ${formatDuration(technique.totalSeconds)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (canAdvance)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '已满足进阶条件',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (exam != null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '考核：${exam!.status.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续修炼'),
                  ),
                  if (canAdvance)
                    FilledButton.icon(
                      onPressed: onAdvance,
                      icon: const Icon(Icons.trending_up),
                      label: const Text('开始进阶'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.technique,
    required this.onStatusChanged,
    required this.onPass,
    required this.onFail,
  });
  final AdvancementExam exam;
  final Technique? technique;
  final ValueChanged<ExamStatus> onStatusChanged;
  final VoidCallback onPass;
  final VoidCallback onFail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeading(
              icon: Icons.assignment_outlined,
              title: '阶段考核',
              trailing: _StatusPill(label: exam.status.label),
            ),
            const SizedBox(height: 14),
            Text(
              '${technique?.name ?? '功法'} · ${stageForLevel(exam.fromLevel).name} → ${stageForLevel(exam.toLevel).name}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(exam.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              exam.objective,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (exam.status == ExamStatus.notStarted)
                  OutlinedButton.icon(
                    onPressed: () => onStatusChanged(ExamStatus.inProgress),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始项目'),
                  ),
                if (exam.status == ExamStatus.inProgress)
                  OutlinedButton.icon(
                    onPressed: () => onStatusChanged(ExamStatus.pendingReview),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('提交验收'),
                  ),
                if (exam.status == ExamStatus.pendingReview) ...[
                  FilledButton.icon(
                    onPressed: onPass,
                    icon: const Icon(Icons.check),
                    label: const Text('通过验收'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onFail,
                    icon: const Icon(Icons.close),
                    label: const Text('未通过'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({
    required this.running,
    required this.elapsedSeconds,
    required this.onPause,
    required this.onFinish,
    required this.onToggleFullscreen,
    required this.isFullscreen,
  });
  final _RunningCultivation running;
  final int elapsedSeconds;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timerText = formatClock(running.displaySeconds(elapsedSeconds));
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isFullscreen ? 48 : 18,
          vertical: isFullscreen ? 44 : 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  running.isCountdown
                      ? Icons.hourglass_bottom_rounded
                      : Icons.timer_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  running.isCountdown ? '倒计时修炼' : '正在修炼',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              running.technique?.name ?? running.type.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              timerText,
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              running.isCountdown ? '剩余时间' : '已专注时间',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onPause,
                  icon: Icon(
                    running.pausedAt == null ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(running.pausedAt == null ? '暂停' : '继续'),
                ),
                FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.stop),
                  label: const Text('结束修炼'),
                ),
                IconButton.filledTonal(
                  tooltip: isFullscreen ? '退出全屏计时' : '全屏计时',
                  onPressed: onToggleFullscreen,
                  icon: Icon(
                    isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenTimerView extends StatefulWidget {
  const _FullscreenTimerView({required this.running, required this.onExit});

  final _RunningCultivation running;
  final VoidCallback onExit;

  @override
  State<_FullscreenTimerView> createState() => _FullscreenTimerViewState();
}

class _FullscreenTimerViewState extends State<_FullscreenTimerView> {
  late final FocusNode _focusNode = FocusNode();
  Timer? _ticker;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _syncTime();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _syncTime());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncTime() {
    if (!mounted) return;
    setState(() {
      _seconds = widget.running.displaySeconds(
        widget.running.effectiveSeconds(DateTime.now().toUtc()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fontSize = math.min(size.height * 0.24, size.width * 0.17);
    final time = formatClock(_seconds);

    return Material(
      color: Colors.black,
      child: DefaultTextStyle(
        style: const TextStyle(
          inherit: false,
          color: Colors.white,
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              widget.onExit();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onExit,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: _FlipClock(time: time, fontSize: fontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipClock extends StatelessWidget {
  const _FlipClock({required this.time, required this.fontSize});

  final String time;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final digitWidth = fontSize * 0.62;
    final separatorWidth = fontSize * 0.28;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final character in time.split(''))
          if (character == ':')
            SizedBox(
              width: separatorWidth,
              child: Text(
                character,
                textAlign: TextAlign.center,
                style: _clockTextStyle(fontSize),
              ),
            )
          else
            SizedBox(
              width: digitWidth,
              child: _FlipDigit(character: character, fontSize: fontSize),
            ),
      ],
    );
  }

  TextStyle _clockTextStyle(double size) => TextStyle(
    inherit: false,
    color: Colors.white,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
    fontFeatures: const [ui.FontFeature.tabularFigures()],
  );
}

class _FlipDigit extends StatelessWidget {
  const _FlipDigit({required this.character, required this.fontSize});

  final String character;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: fontSize * 1.05,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final rotation = Tween<double>(
            begin: -math.pi / 2,
            end: 0,
          ).animate(animation);
          return AnimatedBuilder(
            animation: rotation,
            child: child,
            builder: (context, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(rotation.value),
              child: child,
            ),
          );
        },
        child: Text(
          character,
          key: ValueKey(character),
          textAlign: TextAlign.center,
          style: TextStyle(
            inherit: false,
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            height: 1,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

String _formatCelebrationDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  if (hours > 0 && minutes > 0) return '$hours 小时 $minutes 分钟';
  if (hours > 0) return '$hours 小时';
  if (minutes > 0) return '$minutes 分钟';
  return '${safeSeconds % 60} 秒';
}

class _CultivationCompletionDialog extends StatefulWidget {
  const _CultivationCompletionDialog({required this.session});

  final CultivationSession session;

  @override
  State<_CultivationCompletionDialog> createState() =>
      _CultivationCompletionDialogState();
}

class _CultivationCompletionDialogState
    extends State<_CultivationCompletionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.session;
    final activity = session.type == CultivationType.learning ? '学习' : '锻炼';
    final rewards = <String>[];
    if (session.mentalGained > 0) {
      rewards.add('精神点 +${session.mentalGained}');
    }
    if (session.physicalGained > 0) {
      rewards.add('体质 +${session.physicalGained}');
    }
    if (session.proficiencyGained > 0) {
      rewards.add('功法熟练度 +${session.proficiencyGained}');
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) =>
                  Transform.scale(scale: 1 + _pulse.value * 0.06, child: child),
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  size: 44,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('修炼完成', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              '恭喜您$activity${_formatCelebrationDuration(session.durationSeconds)}',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (rewards.isEmpty)
              Text('本次专注已记录，成长正在累积。')
            else
              ...rewards.map(
                (reward) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    reward,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              '短暂的休息是为了更好的开始，\n请休息 5 分钟再继续吧。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.self_improvement_outlined),
          label: const Text('休息 5 分钟'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 19, color: colors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTechniques extends StatelessWidget {
  const _EmptyTechniques({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('还没有功法'),
            const SizedBox(height: 6),
            const Text('把你正在学习的技能加入修炼体系。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('创建第一门功法'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CultivationDialogIcon extends StatelessWidget {
  const _CultivationDialogIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: colorScheme.onPrimaryContainer),
    );
  }
}

class _CultivationDialogContent extends StatelessWidget {
  const _CultivationDialogContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _CultivationStartValues {
  const _CultivationStartValues({
    required this.type,
    required this.technique,
    required this.note,
    required this.countdownMinutes,
    required this.fullscreen,
  });
  final CultivationType type;
  final Technique? technique;
  final String? note;
  final int? countdownMinutes;
  final bool fullscreen;
}

class _CultivationStartDialog extends StatefulWidget {
  const _CultivationStartDialog({
    required this.techniques,
    this.initialTechnique,
  });
  final List<Technique> techniques;
  final Technique? initialTechnique;
  @override
  State<_CultivationStartDialog> createState() =>
      _CultivationStartDialogState();
}

class _CultivationStartDialogState extends State<_CultivationStartDialog> {
  CultivationType type = CultivationType.learning;
  Technique? technique;
  final note = TextEditingController();
  final countdownMinutes = TextEditingController(text: '60');
  bool countdownEnabled = false;
  bool fullscreen = false;
  String? countdownError;
  @override
  void initState() {
    super.initState();
    technique = widget.initialTechnique;
  }

  @override
  void dispose() {
    note.dispose();
    countdownMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: _CultivationDialogIcon(icon: Icons.timer_outlined),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    titlePadding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
    contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Text('开始修炼'),
    content: _CultivationDialogContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<CultivationType>(
            initialValue: type,
            decoration: const InputDecoration(
              labelText: '修炼类型',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final item in CultivationType.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) => setState(() => type = value ?? type),
          ),
          if (type == CultivationType.learning) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Technique?>(
              initialValue: technique,
              decoration: const InputDecoration(
                labelText: '功法（可选）',
                prefixIcon: Icon(Icons.auto_awesome_outlined),
              ),
              items: [
                const DropdownMenuItem<Technique?>(
                  value: null,
                  child: Text('普通学习'),
                ),
                for (final item in widget.techniques)
                  DropdownMenuItem(value: item, child: Text(item.name)),
              ],
              onChanged: (value) => setState(() => technique = value),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: countdownEnabled,
            onChanged: (value) => setState(() => countdownEnabled = value),
            title: const Text('开启倒计时'),
            secondary: const Icon(Icons.hourglass_bottom_outlined),
          ),
          if (countdownEnabled) ...[
            const SizedBox(height: 8),
            TextField(
              controller: countdownMinutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '倒计时分钟',
                prefixIcon: Icon(Icons.schedule_outlined),
                suffixText: '分钟',
              ),
              onChanged: (_) {
                if (countdownError != null) {
                  setState(() => countdownError = null);
                }
              },
            ),
            if (countdownError != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 16),
                  child: Text(
                    countdownError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: fullscreen,
            onChanged: (value) => setState(() => fullscreen = value),
            title: const Text('开始后进入全屏计时'),
            secondary: const Icon(Icons.fullscreen_outlined),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: () {
          final minutes = int.tryParse(countdownMinutes.text);
          if (countdownEnabled && (minutes == null || minutes < 1)) {
            setState(() => countdownError = '请输入至少 1 分钟');
            return;
          }
          Navigator.pop(
            context,
            _CultivationStartValues(
              type: type,
              technique: type == CultivationType.learning ? technique : null,
              note: note.text,
              countdownMinutes: countdownEnabled ? minutes : null,
              fullscreen: fullscreen,
            ),
          );
        },
        label: const Text('开始'),
      ),
    ],
  );
}

class _TechniqueFormValues {
  const _TechniqueFormValues({
    required this.name,
    required this.description,
    required this.category,
  });
  final String name;
  final String? description;
  final String? category;
}

class _TechniqueEditorDialog extends StatefulWidget {
  const _TechniqueEditorDialog({this.technique});
  final Technique? technique;
  @override
  State<_TechniqueEditorDialog> createState() => _TechniqueEditorDialogState();
}

class _TechniqueEditorDialogState extends State<_TechniqueEditorDialog> {
  late final TextEditingController name = TextEditingController(
    text: widget.technique?.name,
  );
  late final TextEditingController description = TextEditingController(
    text: widget.technique?.description,
  );
  late final TextEditingController category = TextEditingController(
    text: widget.technique?.category,
  );
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: _CultivationDialogIcon(icon: Icons.auto_awesome_outlined),
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    titlePadding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
    contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Text(widget.technique == null ? '创建功法' : '编辑功法'),
    content: _CultivationDialogContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '名称',
              prefixIcon: Icon(Icons.title_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: category,
            decoration: const InputDecoration(
              labelText: '领域 / 分类',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '描述',
              prefixIcon: Icon(Icons.subject_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton.icon(
        icon: const Icon(Icons.save_outlined),
        onPressed: () => Navigator.pop(
          context,
          _TechniqueFormValues(
            name: name.text,
            description: description.text,
            category: category.text,
          ),
        ),
        label: const Text('保存'),
      ),
    ],
  );
}

class _ExamFormValues {
  const _ExamFormValues({
    required this.title,
    required this.objective,
    required this.acceptanceCriteria,
    required this.note,
  });
  final String title;
  final String objective;
  final String acceptanceCriteria;
  final String? note;
}

class _ExamEditorDialog extends StatefulWidget {
  const _ExamEditorDialog({required this.technique});
  final Technique technique;
  @override
  State<_ExamEditorDialog> createState() => _ExamEditorDialogState();
}

class _ExamEditorDialogState extends State<_ExamEditorDialog> {
  final title = TextEditingController();
  final objective = TextEditingController();
  final criteria = TextEditingController();
  final note = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    objective.dispose();
    criteria.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.technique.name} · 创建阶段考核'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '考核名称'),
          ),
          TextField(
            controller: objective,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '目标描述'),
          ),
          TextField(
            controller: criteria,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '验收标准'),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _ExamFormValues(
            title: title.text,
            objective: objective.text,
            acceptanceCriteria: criteria.text,
            note: note.text,
          ),
        ),
        child: const Text('创建考核'),
      ),
    ],
  );
}

class _RealmTrialFormValues {
  const _RealmTrialFormValues({
    required this.title,
    required this.objective,
    required this.acceptanceCriteria,
    required this.note,
  });

  final String title;
  final String objective;
  final String acceptanceCriteria;
  final String? note;
}

class _RealmTrialEditorDialog extends StatefulWidget {
  const _RealmTrialEditorDialog({required this.next});

  final UserRealm next;

  @override
  State<_RealmTrialEditorDialog> createState() =>
      _RealmTrialEditorDialogState();
}

class _RealmTrialEditorDialogState extends State<_RealmTrialEditorDialog> {
  late final TextEditingController title = TextEditingController(
    text: widget.next.trialTemplate.title,
  );
  late final TextEditingController objective = TextEditingController(
    text: widget.next.trialTemplate.objective,
  );
  late final TextEditingController criteria = TextEditingController(
    text: widget.next.trialTemplate.acceptanceCriteria,
  );
  final note = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    objective.dispose();
    criteria.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('开始突破 · ${widget.next.name}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '试炼名称'),
          ),
          TextField(
            controller: objective,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '试炼目标'),
          ),
          TextField(
            controller: criteria,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '验收标准'),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _RealmTrialFormValues(
            title: title.text,
            objective: objective.text,
            acceptanceCriteria: criteria.text,
            note: note.text,
          ),
        ),
        child: const Text('创建试炼'),
      ),
    ],
  );
}
