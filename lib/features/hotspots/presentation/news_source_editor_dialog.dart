import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/news_source.dart';

class NewsSourceEditorDialog extends StatefulWidget {
  const NewsSourceEditorDialog({super.key, this.initial});

  final NewsSourceConfig? initial;

  @override
  State<NewsSourceEditorDialog> createState() => _NewsSourceEditorDialogState();
}

class _NewsSourceEditorDialogState extends State<NewsSourceEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _pageController;
  late final TextEditingController _pageSizeController;
  final _formKey = GlobalKey<FormState>();
  late NewsResponseType _responseType;
  late NewsApiKeyLocation _apiKeyLocation;
  late final TextEditingController _apiKeyParameterController;

  @override
  void initState() {
    super.initState();
    final source = widget.initial;
    _nameController = TextEditingController(text: source?.name ?? '');
    _endpointController = TextEditingController(text: source?.endpoint ?? '');
    _apiKeyController = TextEditingController(text: source?.apiKey ?? '');
    _pageController = TextEditingController(text: '${source?.page ?? 1}');
    _pageSizeController = TextEditingController(
      text: '${source?.pageSize ?? 10}',
    );
    _responseType = source?.responseType ?? NewsResponseType.json;
    _apiKeyLocation = source?.apiKeyLocation ?? NewsApiKeyLocation.auto;
    _apiKeyParameterController = TextEditingController(
      text: source?.apiKeyParameter ?? 'key',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    _pageController.dispose();
    _pageSizeController.dispose();
    _apiKeyParameterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增信息源' : '编辑信息源'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? '请输入信息源名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: '请求地址',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri != null &&
                            (uri.scheme == 'http' || uri.scheme == 'https')
                        ? null
                        : '请输入有效的 HTTP 或 HTTPS 地址';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key（可选）',
                    prefixIcon: Icon(Icons.key_outlined),
                    helperText: '只保存到系统安全存储',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NewsApiKeyLocation>(
                  initialValue: _apiKeyLocation,
                  decoration: const InputDecoration(
                    labelText: 'API Key delivery',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  items: [
                    for (final location in NewsApiKeyLocation.values)
                      DropdownMenuItem(
                        value: location,
                        child: Text(location.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _apiKeyLocation = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyParameterController,
                  enabled: _apiKeyLocation != NewsApiKeyLocation.bearer,
                  decoration: const InputDecoration(
                    labelText: 'Query parameter name',
                    hintText: 'key',
                    prefixIcon: Icon(Icons.tune_outlined),
                    helperText:
                        'Auto detects TianAPI, Juhe, and declared URL parameters',
                  ),
                  validator: (value) =>
                      _apiKeyLocation == NewsApiKeyLocation.bearer ||
                          value?.trim().isNotEmpty == true
                      ? null
                      : 'Enter a query parameter name',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NewsResponseType>(
                  initialValue: _responseType,
                  decoration: const InputDecoration(
                    labelText: '返回数据类型',
                    prefixIcon: Icon(Icons.data_object_outlined),
                  ),
                  items: [
                    for (final type in NewsResponseType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _responseType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '页码 page',
                          prefixIcon: Icon(Icons.looks_one_outlined),
                        ),
                        validator: _positiveNumberValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pageSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '条数 num',
                          prefixIcon: Icon(Icons.format_list_numbered),
                        ),
                        validator: _positiveNumberValidator,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final source = widget.initial;
    Navigator.of(context).pop(
      NewsSourceConfig(
        id: source?.id ?? Uuid().v4(),
        name: _nameController.text.trim(),
        endpoint: _endpointController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        responseType: _responseType,
        apiKeyLocation: _apiKeyLocation,
        apiKeyParameter: _apiKeyParameterController.text.trim(),
        enabled: source?.enabled ?? true,
        page: int.parse(_pageController.text),
        pageSize: int.parse(_pageSizeController.text),
      ),
    );
  }

  String? _positiveNumberValidator(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed != null && parsed > 0 ? null : '请输入正整数';
  }
}
