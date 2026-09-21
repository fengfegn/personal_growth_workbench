import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/cultivation_providers.dart';
import '../domain/realm.dart';

class RealmDetailPage extends ConsumerWidget {
  const RealmDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(cultivationDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('境界详情')),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('读取境界失败：$error')),
        data: (data) {
          final progress = data.realmProgress;
          final next = progress.realm;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('当前境界', style: Theme.of(context).textTheme.titleMedium),
              Text(
                data.currentRealm.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(data.currentRealm.description),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: next == null
                      ? const Text('当前版本最高境界')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('下一境界：${next.name}'),
                            const SizedBox(height: 12),
                            Text(
                              '精神：${data.profile.mentalPoints} / ${next.requiredMental}',
                            ),
                            LinearProgressIndicator(
                              value: progress.mentalRatio,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '体质：${data.profile.physicalPoints} / ${next.requiredPhysical}',
                            ),
                            LinearProgressIndicator(
                              value: progress.physicalRatio,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '当前瓶颈：${_bottleneckLabel(progress.bottleneck)}',
                            ),
                            Text(
                              '预计还需：学习约 ${_hours(progress.mentalTrainingSeconds)} · 锻炼约 ${_hours(progress.physicalTrainingSeconds)}',
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text('境界路线', style: Theme.of(context).textTheme.titleLarge),
              Card(
                child: Column(
                  children: [
                    for (final realm in userRealms)
                      ListTile(
                        leading: Icon(
                          realm.index < data.profile.currentRealm
                              ? Icons.check_circle
                              : realm.index == data.profile.currentRealm
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: realm.index <= data.profile.currentRealm
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(realm.name),
                        subtitle: Text(
                          '精神 ${realm.requiredMental} · 体质 ${realm.requiredPhysical}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('突破历史', style: Theme.of(context).textTheme.titleLarge),
              if (data.realmHistory.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('还没有突破记录。'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final item in data.realmHistory)
                        ListTile(
                          title: Text(
                            '${realmForIndex(item.fromRealm).name} → ${realmForIndex(item.toRealm).name}',
                          ),
                          subtitle: Text(
                            '精神 ${item.mentalAtBreakthrough} · 体质 ${item.physicalAtBreakthrough}',
                          ),
                          trailing: Text(item.advancedAt.toLocal().toString()),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
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

  String _hours(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分钟';
  }
}
