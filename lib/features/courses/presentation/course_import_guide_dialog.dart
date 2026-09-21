import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CoursePromptFormat { json, markdown }

class CourseImportGuideDialog extends StatefulWidget {
  const CourseImportGuideDialog({super.key});

  @override
  State<CourseImportGuideDialog> createState() =>
      _CourseImportGuideDialogState();
}

class _CourseImportGuideDialogState extends State<CourseImportGuideDialog> {
  CoursePromptFormat _format = CoursePromptFormat.json;
  bool _copied = false;

  String get _prompt => switch (_format) {
    CoursePromptFormat.json => _jsonPrompt,
    CoursePromptFormat.markdown => _markdownPrompt,
  };

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  void _changeFormat(CoursePromptFormat format) {
    setState(() {
      _format = format;
      _copied = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('先用 AI 整理课表'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '如果原始课表无法直接识别，可以复制下面任一提示词，连同原始课表一起发给 ChatGPT。处理完成后，将返回的 JSON 或 Markdown 文件保存到本地，再回到工作台导入。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<CoursePromptFormat>(
                segments: const [
                  ButtonSegment(
                    value: CoursePromptFormat.json,
                    label: Text('JSON 版'),
                    icon: Icon(Icons.data_object),
                  ),
                  ButtonSegment(
                    value: CoursePromptFormat.markdown,
                    label: Text('Markdown 版'),
                    icon: Icon(Icons.table_chart_outlined),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selection) =>
                    _changeFormat(selection.first),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 280),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SelectableText(
                  _prompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const ValueKey('course-copy-prompt'),
                  onPressed: _copyPrompt,
                  icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                  label: Text(_copied ? '已复制' : '复制此提示词'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后导入'),
        ),
        FilledButton.icon(
          key: const ValueKey('course-select-import-file'),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('选择文件导入'),
        ),
      ],
    );
  }
}

const _jsonPrompt = '''请将我接下来提供的原始课程表转换为课程表工作台可直接导入的 JSON。

要求：
1. 只输出合法 JSON，不要输出 Markdown 代码围栏、解释文字或其他内容。
2. 顶层必须包含两个数组：courses 和 sessions。
3. courses 的每项至少包含 name；可包含唯一的 id、teacher、classroom、color、note。
4. sessions 的每项必须包含 courseId、date、startTime、endTime；可包含 slotStart、slotEnd、note。
5. courseId 必须对应 courses 中的 id；date 使用 YYYY-MM-DD；startTime 和 endTime 使用 HH:mm。
6. 节次按原课表填写，例如 1-2、3-4、5-6、7-8、晚课分别使用 1/2、3/4、5/6、7/8、9/10。若原文有准确时间，优先保留准确时间。
7. 保留原始课表中的每一次上课、课程名称、教师、教室和备注；空白单元格不要生成课程，不要自行编造信息。
8. 如果原始课表中的日期不完整，请根据课表中明确给出的学期、周次和星期推算；无法确定的字段不要猜测。

请处理以下原始课程表：
[在这里粘贴原始课程表]''';

const _markdownPrompt = '''请将我接下来提供的原始课程表转换为课程表工作台可直接导入的 Markdown。

要求：
1. 只输出原始 Markdown 表格，不要输出代码围栏、解释文字或其他内容。
2. 第一行表头必须是“| 时间 | 周一 YYYY-MM-DD | 周二 YYYY-MM-DD | 周三 YYYY-MM-DD | 周四 YYYY-MM-DD | 周五 YYYY-MM-DD | 周六 YYYY-MM-DD | 周日 YYYY-MM-DD |”。日期必须包含四位年份。
3. 第二行必须是 Markdown 分隔行：|---|---|---|---|---|---|---|---|。
4. 后面固定使用五行：1-2 08:30-10:05、3-4 10:25-12:00、5-6 13:30-15:05、7-8 15:25-17:00、晚课 18:00-20:30。
5. 每个有课的单元格只填写课程名称；没有课的单元格留空。Markdown 版只保留课程名称，教师、教室和备注等附加字段请使用 JSON 版。
6. 同一天同一课程连续占用下一行时，下一行使用“↳ 课程名称”；不要重复创建不同课程，也不要合并不连续的课程。
7. 保留原始课表中的每一次上课，不要自行编造日期或课程；如果日期不完整，请根据课表中明确给出的学期、周次和星期推算。

请处理以下原始课程表：
[在这里粘贴原始课程表]''';
