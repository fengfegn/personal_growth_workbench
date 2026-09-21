import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/cultivation_providers.dart';
import '../domain/cultivation.dart';
import '../domain/cultivation_settlement.dart';

class TechniqueDetailPage extends ConsumerWidget {
  const TechniqueDetailPage({required this.techniqueId, super.key});
  final String techniqueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technique = ref.watch(techniqueDetailProvider(techniqueId));
    final sessions = ref.watch(techniqueSessionsProvider(techniqueId));
    final history = ref.watch(techniqueHistoryProvider(techniqueId));
    return Scaffold(
      appBar: AppBar(title: const Text('功法详情')),
      body: technique.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取功法失败：$error')),
        data: (item) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            if (item.category?.isNotEmpty == true) Text(item.category!),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前境界：${item.stage.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '熟练度：${item.proficiency} / ${item.nextStage?.requiredProficiency ?? item.proficiency}',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.nextStage == null
                          ? 1
                          : (item.proficiency /
                                    item.nextStage!.requiredProficiency)
                                .clamp(0, 1),
                    ),
                    const SizedBox(height: 8),
                    Text('累计修炼：${formatDuration(item.totalSeconds)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('境界进度', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final stage in cultivationStages)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          stage.level <= item.level
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: stage.level <= item.level
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(stage.name),
                        subtitle: Text('${stage.requiredProficiency}+ 熟练度'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('修炼历史', style: Theme.of(context).textTheme.titleLarge),
            sessions.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text('读取历史失败：$error'),
              data: (items) => items.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('还没有修炼记录。'),
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (final session in items)
                            ListTile(
                              title: Text(
                                formatDuration(session.durationSeconds),
                              ),
                              subtitle: Text(
                                '${session.type.label} · ${session.endedAt.toLocal()}',
                              ),
                              trailing: Text(
                                session.proficiencyGained > 0
                                    ? '+${session.proficiencyGained}'
                                    : '',
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Text('晋升历史', style: Theme.of(context).textTheme.titleLarge),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text('读取晋升历史失败：$error'),
              data: (items) => items.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('还没有晋升记录。'),
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (final entry in items)
                            ListTile(
                              title: Text(
                                '${stageForLevel(entry.fromLevel).name} → ${stageForLevel(entry.toLevel).name}',
                              ),
                              subtitle: Text(
                                entry.advancedAt.toLocal().toString(),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
