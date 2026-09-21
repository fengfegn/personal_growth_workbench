import 'dart:convert';

enum AiProviderKind {
  chatGpt(
    'ChatGPT',
    'https://api.openai.com/v1/chat/completions',
    'gpt-4o-mini',
  ),
  deepSeek(
    'DeepSeek',
    'https://api.deepseek.com/chat/completions',
    'deepseek-chat',
  ),
  kimi('Kimi', 'https://api.moonshot.cn/v1/chat/completions', 'moonshot-v1-8k');

  const AiProviderKind(this.label, this.defaultEndpoint, this.defaultModel);

  final String label;
  final String defaultEndpoint;
  final String defaultModel;

  static AiProviderKind fromStorage(String value) {
    return AiProviderKind.values.firstWhere(
      (provider) => provider.name == value,
      orElse: () => AiProviderKind.chatGpt,
    );
  }
}

class AiProviderConfig {
  const AiProviderConfig({
    required this.provider,
    required this.endpoint,
    required this.model,
    required this.enabled,
  });

  factory AiProviderConfig.defaults() {
    const provider = AiProviderKind.chatGpt;
    return AiProviderConfig(
      provider: provider,
      endpoint: provider.defaultEndpoint,
      model: provider.defaultModel,
      enabled: false,
    );
  }

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    final provider = AiProviderKind.fromStorage(
      json['provider'] as String? ?? '',
    );
    return AiProviderConfig(
      provider: provider,
      endpoint: (json['endpoint'] as String?)?.trim().isNotEmpty == true
          ? (json['endpoint'] as String).trim()
          : provider.defaultEndpoint,
      model: (json['model'] as String?)?.trim().isNotEmpty == true
          ? (json['model'] as String).trim()
          : provider.defaultModel,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  final AiProviderKind provider;
  final String endpoint;
  final String model;
  final bool enabled;

  AiProviderConfig copyWith({
    AiProviderKind? provider,
    String? endpoint,
    String? model,
    bool? enabled,
  }) {
    return AiProviderConfig(
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'endpoint': endpoint,
    'model': model,
    'enabled': enabled,
  };

  String toJsonString() => jsonEncode(toJson());
}

class AiProviderSettings {
  const AiProviderSettings({required this.config, required this.apiKey});

  final AiProviderConfig config;
  final String apiKey;

  bool get isConfigured => config.enabled && apiKey.trim().isNotEmpty;
}
