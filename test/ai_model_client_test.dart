import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/features/ai/domain/ai_provider.dart';
import 'package:personal_growth_workbench/features/hotspots/data/ai_model_client.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/news_source.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() => server.close());

  test(
    'selects only model-returned article ids in one compatible request',
    () async {
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        expect(request.method, 'POST');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer model-secret',
        );
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        expect(body['model'], 'deepseek-chat');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{"urls":["brief-tech"]}'},
              },
            ],
          }),
        );
        await request.response.close();
      });

      final settings = AiProviderSettings(
        config: AiProviderConfig(
          provider: AiProviderKind.deepSeek,
          endpoint:
              'http://${server.address.host}:${server.port}/chat/completions',
          model: 'deepseek-chat',
          enabled: true,
        ),
        apiKey: 'model-secret',
      );
      final selected = await OpenAiCompatibleClient(settings)
          .selectTopArticles([
            const NewsArticle(
              sourceName: 'Source',
              title: 'Technology policy update',
              summary: 'Summary',
              url: 'brief-tech',
              publishedAt: null,
            ),
            const NewsArticle(
              sourceName: 'Source',
              title: 'Celebrity gossip',
              summary: 'Summary',
              url: 'brief-gossip',
              publishedAt: null,
            ),
          ]);

      expect(requestCount, 1);
      expect(selected.map((article) => article.url), ['brief-tech']);
    },
  );
}
