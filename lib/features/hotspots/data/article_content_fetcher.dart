import 'dart:convert';
import 'dart:io';

import '../domain/news_source.dart';

abstract class ArticleContentFetcher {
  Future<List<NewsArticle>> enrich(List<NewsArticle> articles);
}

class PythonArticleContentFetcher implements ArticleContentFetcher {
  PythonArticleContentFetcher({Directory? workingDirectory})
    : _workingDirectory = workingDirectory ?? Directory.current;

  final Directory _workingDirectory;

  @override
  Future<List<NewsArticle>> enrich(List<NewsArticle> articles) async {
    final targets = articles
        .where((article) => article.url.isNotEmpty)
        .toList();
    if (targets.isEmpty) {
      return articles;
    }
    final script = File(
      '${_workingDirectory.path}${Platform.pathSeparator}scripts'
      '${Platform.pathSeparator}fetch_article_content.py',
    );
    if (!script.existsSync()) {
      return articles;
    }

    String? output;
    var succeeded = false;
    for (final executable
        in Platform.isWindows
            ? const ['python', 'py']
            : const ['python3', 'python']) {
      try {
        final process = await Process.start(executable, [
          script.path,
        ], workingDirectory: _workingDirectory.path);
        process.stdin.write(
          jsonEncode([
            for (final article in targets) {'url': article.url},
          ]),
        );
        await process.stdin.close();
        final processOutput = await process.stdout
            .transform(utf8.decoder)
            .join();
        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          output = processOutput;
          succeeded = true;
          break;
        }
      } on Object {
        output = null;
      }
    }
    final rawOutput = output;
    if (!succeeded || rawOutput == null) {
      return articles;
    }

    try {
      final decoded = jsonDecode(rawOutput);
      if (decoded is! List) {
        return articles;
      }
      final contentByUrl = <String, String>{};
      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        final url = item['url'];
        final content = item['content'];
        if (url is String && content is String && content.trim().isNotEmpty) {
          contentByUrl[url] = content.trim();
        }
      }
      return [
        for (final article in articles)
          article.copyWith(
            content: contentByUrl[article.url] ?? article.content,
          ),
      ];
    } on Object {
      return articles;
    }
  }
}
