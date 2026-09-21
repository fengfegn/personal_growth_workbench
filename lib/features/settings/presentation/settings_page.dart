import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_controller.dart';
import '../../ai/domain/ai_provider.dart';
import '../../hotspots/application/hotspot_providers.dart';
import '../../hotspots/data/ai_brief_cache_repository.dart';
import '../../hotspots/data/ai_model_client.dart';
import '../../hotspots/domain/news_source.dart';
import '../../hotspots/presentation/news_source_editor_dialog.dart';
import '../../workbench/application/workbench_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _nicknameController = TextEditingController();
  final _nicknameFormKey = GlobalKey<FormState>();
  bool _nicknameInitialized = false;
  final _aiEndpointController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _briefRequestLimitController = TextEditingController();
  final _aiFormKey = GlobalKey<FormState>();
  List<NewsSourceConfig> _newsSources = [];
  AiProviderKind _aiProvider = AiProviderKind.chatGpt;
  bool _aiEnabled = false;
  bool _aiInitialized = false;
  bool _sourcesInitialized = false;
  bool _aiSaving = false;
  bool _aiTesting = false;
  bool _sourcesSaving = false;
  bool _briefLimitInitialized = false;
  bool _briefLimitSaving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _aiEndpointController.dispose();
    _aiModelController.dispose();
    _apiKeyController.dispose();
    _briefRequestLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(displayModeProvider);
    final palette = ref.watch(themePaletteProvider);
    final profile = ref.watch(userProfileProvider);
    final aiSettings = ref.watch(aiSettingsProvider);
    final newsSources = ref.watch(newsSourceSettingsProvider);
    final briefBudget = ref.watch(aiBriefRequestBudgetProvider);
    profile.whenData((value) {
      if (!_nicknameInitialized) {
        _nicknameController.text = value.nickname;
        _nicknameInitialized = true;
      }
    });
    aiSettings.whenData((value) {
      if (!_aiInitialized) {
        _aiProvider = value.config.provider;
        _aiEndpointController.text = value.config.endpoint;
        _aiModelController.text = value.config.model;
        _apiKeyController.text = value.apiKey;
        _aiEnabled = value.config.enabled;
        _aiInitialized = true;
      }
    });
    newsSources.whenData((value) {
      if (!_sourcesInitialized) {
        _newsSources = [...value];
        _sourcesInitialized = true;
      }
    });
    briefBudget.whenData((value) {
      if (!_briefLimitInitialized) {
        _briefRequestLimitController.text = '${value.maxRequests}';
        _briefLimitInitialized = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('个人资料', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Form(
            key: _nicknameFormKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(labelText: '昵称'),
                    validator: (value) =>
                        value?.trim().isEmpty == true ? '请输入昵称' : null,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: profile.isLoading ? null : _saveNickname,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存昵称'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('AI 与每日热点', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildAiSettings(context, aiSettings, newsSources),
          const SizedBox(height: 20),
          _buildBriefRequestLimit(context, briefBudget),
          const SizedBox(height: 32),
          Text('外观', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('显示模式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<DisplayMode>(
            segments: [
              for (final mode in DisplayMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {displayMode},
            onSelectionChanged: (selection) {
              ref.read(displayModeProvider.notifier).state = selection.first;
            },
          ),
          const SizedBox(height: 24),
          Text('人民币灵感色系', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<ThemePalette>(
            initialValue: palette,
            decoration: const InputDecoration(labelText: '主题预览'),
            items: [
              for (final option in ThemePalette.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                unawaited(
                  ref.read(themePaletteProvider.notifier).setPalette(value),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in ThemePalette.values)
                _ThemePreviewTile(
                  palette: option,
                  selected: option == palette,
                  onTap: () {
                    unawaited(
                      ref
                          .read(themePaletteProvider.notifier)
                          .setPalette(option),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveNickname() async {
    if (!_nicknameFormKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(userProfileRepositoryProvider)
        .updateNickname(_nicknameController.text);
    ref.invalidate(userProfileProvider);
    ref.invalidate(dashboardDataProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称已保存，本地数据已经保存')));
    }
  }

  Widget _buildAiSettings(
    BuildContext context,
    AsyncValue<AiProviderSettings> aiSettings,
    AsyncValue<List<NewsSourceConfig>> newsSources,
  ) {
    return aiSettings.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text('读取 AI 配置失败：$error'),
      data: (_) => Form(
        key: _aiFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AiProviderKind>(
              initialValue: _aiProvider,
              decoration: const InputDecoration(
                labelText: '大模型厂商',
                prefixIcon: Icon(Icons.auto_awesome_outlined),
              ),
              items: [
                for (final provider in AiProviderKind.values)
                  DropdownMenuItem(
                    value: provider,
                    child: Text(provider.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _aiProvider = value;
                  _aiEndpointController.text = value.defaultEndpoint;
                  _aiModelController.text = value.defaultModel;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aiEndpointController,
              decoration: const InputDecoration(
                labelText: 'API Endpoint',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              validator: (value) =>
                  Uri.tryParse(value?.trim() ?? '')?.hasScheme == true
                  ? null
                  : '请输入有效的 API 地址',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aiModelController,
              decoration: const InputDecoration(
                labelText: '模型名称',
                prefixIcon: Icon(Icons.memory_outlined),
              ),
              validator: (value) =>
                  value?.trim().isEmpty == true ? '请输入模型名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                prefixIcon: Icon(Icons.key_outlined),
                helperText: '密钥只保存到系统安全存储，不写入普通数据库',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用大模型热点总结'),
              value: _aiEnabled,
              onChanged: (value) => setState(() => _aiEnabled = value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _aiSaving || _aiTesting ? null : _saveAiSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_aiSaving ? '保存中...' : '保存 AI 配置'),
                ),
                OutlinedButton.icon(
                  onPressed: _aiSaving || _aiTesting ? null : _testAiConnection,
                  icon: _aiTesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_outlined),
                  label: Text(_aiTesting ? '测试中...' : '测试 AI 连接'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildNewsSources(context, newsSources),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsSources(
    BuildContext context,
    AsyncValue<List<NewsSourceConfig>> newsSources,
  ) {
    return newsSources.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text('读取信息源失败：$error'),
      data: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '信息源',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _sourcesSaving ? null : _addNewsSource,
                icon: const Icon(Icons.add_outlined),
                label: const Text('新增信息源'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '支持自定义新闻、政策或数据接口；API Key 仅保存在系统安全存储中。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (_newsSources.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('尚未添加信息源'),
              subtitle: Text('新增后保存即可用于每日热点采集'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _newsSources.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = _newsSources[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    source.responseType == NewsResponseType.rss
                        ? Icons.rss_feed_outlined
                        : Icons.source_outlined,
                  ),
                  title: Text(source.name),
                  subtitle: Text(
                    '${source.endpoint}\n${source.responseType.label} · '
                    'page ${source.page} · num ${source.pageSize} · '
                    '${source.apiKey.isEmpty ? '未配置 API Key' : '已配置 API Key'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      Switch(
                        value: source.enabled,
                        onChanged: _sourcesSaving
                            ? null
                            : (value) => setState(
                                () => _newsSources[index] = source.copyWith(
                                  enabled: value,
                                ),
                              ),
                      ),
                      IconButton(
                        tooltip: '编辑信息源',
                        onPressed: _sourcesSaving
                            ? null
                            : () => _editNewsSource(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除信息源',
                        onPressed: _sourcesSaving
                            ? null
                            : () => _removeNewsSource(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _sourcesSaving ? null : _saveNewsSources,
              icon: const Icon(Icons.save_outlined),
              label: Text(_sourcesSaving ? '保存中...' : '保存信息源'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefRequestLimit(
    BuildContext context,
    AsyncValue<AiBriefRequestBudget> budget,
  ) {
    return budget.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) =>
          Text('Could not load request limit: $error'),
      data: (value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _briefRequestLimitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Daily AI brief request limit',
                helperText:
                    '${value.usedRequests}/${value.maxRequests} requests used today',
                prefixIcon: const Icon(Icons.savings_outlined),
              ),
              validator: (input) {
                final parsed = int.tryParse(input?.trim() ?? '');
                return parsed != null && parsed >= 1 && parsed <= 100
                    ? null
                    : 'Enter a whole number from 1 to 100';
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _briefLimitSaving ? null : _saveBriefRequestLimit,
            icon: const Icon(Icons.save_outlined),
            label: Text(_briefLimitSaving ? 'Saving...' : 'Save limit'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewsSource() async {
    final source = await showDialog<NewsSourceConfig>(
      context: context,
      builder: (context) => const NewsSourceEditorDialog(),
    );
    if (source != null && mounted) {
      setState(() => _newsSources = [..._newsSources, source]);
    }
  }

  Future<void> _editNewsSource(int index) async {
    final source = await showDialog<NewsSourceConfig>(
      context: context,
      builder: (context) =>
          NewsSourceEditorDialog(initial: _newsSources[index]),
    );
    if (source != null && mounted) {
      setState(() => _newsSources[index] = source);
    }
  }

  Future<void> _removeNewsSource(int index) async {
    final source = _newsSources[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除信息源？'),
        content: Text('删除后将不再从“${source.name}”采集热点。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _newsSources = [..._newsSources]..removeAt(index);
      });
    }
  }

  Future<void> _saveAiSettings() async {
    if (!_aiFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _aiSaving = true);
    try {
      await ref
          .read(aiSettingsRepositoryProvider)
          .saveSettings(
            AiProviderSettings(
              config: AiProviderConfig(
                provider: _aiProvider,
                endpoint: _aiEndpointController.text.trim(),
                model: _aiModelController.text.trim(),
                enabled: _aiEnabled,
              ),
              apiKey: _apiKeyController.text,
            ),
          );
      invalidateHotspotData(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI 与信息源配置已保存到本地')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('配置保存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _aiSaving = false);
      }
    }
  }

  Future<void> _testAiConnection() async {
    if (!_aiFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _aiTesting = true);
    try {
      await OpenAiCompatibleClient(
        AiProviderSettings(
          config: AiProviderConfig(
            provider: _aiProvider,
            endpoint: _aiEndpointController.text.trim(),
            model: _aiModelController.text.trim(),
            enabled: true,
          ),
          apiKey: _apiKeyController.text,
        ),
      ).verifyConnection();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI 连接成功，筛选热点时可以使用该模型')));
      }
    } on AiModelException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI 连接失败：${error.message}')));
      }
    } finally {
      if (mounted) {
        setState(() => _aiTesting = false);
      }
    }
  }

  Future<void> _saveNewsSources() async {
    setState(() => _sourcesSaving = true);
    try {
      await ref
          .read(newsSourceSettingsRepositoryProvider)
          .saveSources(_newsSources);
      invalidateHotspotData(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('信息源配置已保存到本地')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('信息源保存失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _sourcesSaving = false);
      }
    }
  }

  Future<void> _saveBriefRequestLimit() async {
    final maxRequests = int.tryParse(_briefRequestLimitController.text.trim());
    if (maxRequests == null || maxRequests < 1 || maxRequests > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a daily limit from 1 to 100.')),
      );
      return;
    }
    setState(() => _briefLimitSaving = true);
    try {
      await ref
          .read(aiBriefCacheRepositoryProvider)
          .setMaxRequests(maxRequests);
      ref.invalidate(aiBriefRequestBudgetProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily AI brief request limit saved.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _briefLimitSaving = false);
      }
    }
  }
}

class _ThemePreviewTile extends StatelessWidget {
  const _ThemePreviewTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: palette.label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: palette.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(palette.label)),
            ],
          ),
        ),
      ),
    );
  }
}
