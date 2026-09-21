import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/hotspot_providers.dart';
import '../data/ai_brief_cache_repository.dart';
import '../domain/ai_brief_article.dart';

class HotspotPage extends ConsumerStatefulWidget {
  const HotspotPage({super.key});

  @override
  ConsumerState<HotspotPage> createState() => _HotspotPageState();
}

class _HotspotPageState extends ConsumerState<HotspotPage> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(aiBriefArticlesProvider);
    final budget = ref.watch(aiBriefRequestBudgetProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI News Briefs'),
        actions: [
          IconButton(
            tooltip: 'Update briefs',
            onPressed: _isUpdating ? null : _updateBriefs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: articles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(message: error.toString()),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            budget.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text(error.toString()),
              data: (value) => _BudgetBar(
                budget: value,
                isUpdating: _isUpdating,
                onUpdate: _updateBriefs,
              ),
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              _EmptyState(isUpdating: _isUpdating, onUpdate: _updateBriefs)
            else
              for (final article in items) ...[
                _BriefCard(article: article),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateBriefs() async {
    setState(() => _isUpdating = true);
    try {
      await ref.read(aiBriefRepositoryProvider).refreshArticles();
      ref.invalidate(aiBriefArticlesProvider);
      ref.invalidate(aiBriefRequestBudgetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Briefs updated and saved locally.')),
        );
      }
    } on AiBriefRequestLimitException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Brief update failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.budget,
    required this.isUpdating,
    required this.onUpdate,
  });

  final AiBriefRequestBudget budget;
  final bool isUpdating;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.savings_outlined, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Today: ${budget.usedRequests}/${budget.maxRequests} requests used '
            '(${budget.remainingRequests} remaining)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: isUpdating || budget.remainingRequests < 3
              ? null
              : onUpdate,
          icon: isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(isUpdating ? 'Updating...' : 'Update'),
        ),
      ],
    );
  }
}

class _BriefCard extends ConsumerWidget {
  const _BriefCard({required this.article});

  final AiBriefArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publishedAt = article.publishedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          try {
            final detail = await ref
                .read(aiBriefRepositoryProvider)
                .fetchDetail(article);
            ref.invalidate(aiBriefArticlesProvider);
            ref.invalidate(aiBriefRequestBudgetProvider);
            if (context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => AiBriefDetailPage(article: detail),
                ),
              );
            }
          } on AiBriefRequestLimitException catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.message)));
            }
          } on Object catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not load full brief: $error')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    article.imageUrl,
                    width: 104,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          width: 104,
                          height: 76,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(_typeLabel(article.type))),
                        const Spacer(),
                        if (publishedAt != null)
                          Text(
                            DateFormat(
                              'MM-dd HH:mm',
                            ).format(publishedAt.toLocal()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (article.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        article.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (article.sourceName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.sourceName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class AiBriefDetailPage extends StatelessWidget {
  const AiBriefDetailPage({required this.article, super.key});

  final AiBriefArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brief detail')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Chip(label: Text(_typeLabel(article.type))),
            const SizedBox(height: 12),
            Text(
              article.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (article.sourceName.isNotEmpty)
              Text(
                article.sourceName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (article.summary.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                article.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 24),
            Text(article.content, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isUpdating, required this.onUpdate});

  final bool isUpdating;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.newspaper_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('No cached briefs for today.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isUpdating ? null : onUpdate,
            icon: const Icon(Icons.refresh),
            label: const Text('Update briefs'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

String _typeLabel(String type) {
  return switch (type) {
    'tech' => 'Technology',
    'money' => 'Finance',
    'hot' => 'World / Hot',
    'war' => 'World affairs',
    _ => type.isEmpty ? 'News' : type,
  };
}
