import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/features/hotspots/data/ai_brief_client.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/ai_brief_article.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/news_source.dart';

void main() {
  late HttpServer server;
  late NewsSourceConfig source;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source = NewsSourceConfig(
      name: 'AI brief',
      endpoint:
          'http://${server.address.host}:${server.port}/fapigw/aibrief/list',
      apiKey: 'source-secret',
      page: 2,
      pageSize: 30,
    );
  });

  tearDown(() => server.close());

  test('requests the documented list endpoint and parses articles', () async {
    server.listen((request) {
      expect(request.uri.path, '/fapigw/aibrief/list');
      expect(request.uri.queryParameters, {
        'key': 'source-secret',
        'type': 'tech',
        'page': '2',
        'page_size': '20',
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error_code': 0,
          'reason': 'success',
          'result': {
            'list': [
              {
                'id': 'brief-1',
                'title': 'Semiconductor investment grows',
                'author_name': 'Example News',
                'type': 'tech',
                'summary': 'A technology summary.',
                'publish_date': '2026-08-12 10:30:00',
                'url': 'https://example.com/brief-1',
              },
            ],
          },
        }),
      );
      request.response.close();
    });

    final articles = await AiBriefClient().fetchList(source, type: 'tech');

    expect(articles, hasLength(1));
    expect(articles.single.id, 'brief-1');
    expect(articles.single.type, 'tech');
    expect(articles.single.summary, 'A technology summary.');
  });

  test('requests detail by id and converts HTML content to text', () async {
    server.listen((request) {
      expect(request.uri.path, '/fapigw/aibrief/detail');
      expect(request.uri.queryParameters, {
        'key': 'source-secret',
        'id': 'brief-1',
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error_code': 0,
          'reason': 'success',
          'result': {
            'id': 'brief-1',
            'title': 'Full brief',
            'author_name': 'Example News',
            'type': 'tech',
            'summary': 'A summary.',
            'content':
                '<p>First paragraph.</p><p>Second &amp; final paragraph.</p>',
          },
        }),
      );
      request.response.close();
    });

    final detail = await AiBriefClient().fetchDetail(
      source,
      const AiBriefArticle(
        id: 'brief-1',
        title: 'Brief',
        sourceName: '',
        type: 'tech',
        imageUrl: '',
        summary: '',
        publishedAt: null,
        url: '',
      ),
    );

    expect(detail.content, 'First paragraph.\n\nSecond & final paragraph.');
  });
}
