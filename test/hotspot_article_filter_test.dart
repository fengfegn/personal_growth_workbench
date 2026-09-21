import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/features/hotspots/application/hotspot_article_filter.dart';
import 'package:personal_growth_workbench/features/hotspots/domain/news_source.dart';

NewsArticle _article(String title, {String summary = ''}) {
  return NewsArticle(
    sourceName: 'Test source',
    title: title,
    summary: summary,
    url: 'https://example.com/${title.hashCode}',
    publishedAt: null,
  );
}

void main() {
  test('keeps technology finance and world-affairs articles', () {
    final filtered = HotspotArticleFilter.keepRelevant([
      _article('New semiconductor technology investment'),
      _article('Global trade agreement is announced'),
      _article('Central bank discusses inflation'),
    ]);

    expect(filtered, hasLength(3));
  });

  test('removes entertainment and gossip before model selection', () {
    final filtered = HotspotArticleFilter.keepRelevant([
      _article('Celebrity gossip dominates entertainment news'),
      _article('明星恋情登上娱乐榜'),
      _article('男子捉奸妻子路上先找小姐开房进屋10分钟后结束出门'),
      _article('AI chip supply chain update'),
    ]);

    expect(filtered.map((article) => article.title), [
      'AI chip supply chain update',
    ]);
  });

  test('keeps policy articles', () {
    final filtered = HotspotArticleFilter.keepRelevant([
      _article('国务院发布人工智能产业政策'),
      _article('监管部门公布新的市场法规'),
    ]);

    expect(filtered, hasLength(2));
  });
}
