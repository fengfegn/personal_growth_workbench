import '../domain/news_source.dart';

class HotspotArticleFilter {
  const HotspotArticleFilter._();

  static List<NewsArticle> keepRelevant(List<NewsArticle> articles) {
    return articles.where(_isRelevant).toList(growable: false);
  }

  static bool _isRelevant(NewsArticle article) {
    final text = '${article.title} ${article.summary}'.toLowerCase();
    if (_containsAny(text, _excludedTerms)) {
      return false;
    }
    return _containsAny(text, _relevantTerms);
  }

  static bool _containsAny(String value, Set<String> terms) {
    return terms.any(value.contains);
  }

  static const _excludedTerms = <String>{
    'entertainment',
    'celebrity',
    'gossip',
    'movie',
    'tv show',
    '明星',
    '娱乐',
    '八卦',
    '综艺',
    '影视',
    '艺人',
    '网红',
    '恋情',
    '内娱',
    '私生活',
    '捉奸',
    '出轨',
    '开房',
    '小三',
    '婚恋',
    '离婚',
    '情感',
    '红毯',
    '选秀',
  };

  static const _relevantTerms = <String>{
    'technology',
    'tech',
    'ai',
    'artificial intelligence',
    'semiconductor',
    'chip',
    'software',
    'internet',
    'finance',
    'financial',
    'economy',
    'economic',
    'market',
    'stock',
    'bank',
    'inflation',
    'trade',
    'global',
    'international',
    'policy',
    'government',
    'regulation',
    'regulator',
    'legislation',
    'parliament',
    'diplomacy',
    'foreign policy',
    '科技',
    '人工智能',
    '芯片',
    '半导体',
    '软件',
    '互联网',
    '算力',
    '财经',
    '金融',
    '经济',
    '股市',
    '股票',
    '银行',
    '通胀',
    '贸易',
    '国际',
    '外交',
    '全球',
    '世界',
    '政策',
    '政府',
    '监管',
    '法规',
    '法律',
    '财政',
    '货币',
    '国务院',
    '部委',
    '证监会',
    '工信部',
    '发改委',
    '人大',
    '议会',
    '选举',
    '欧盟',
    '联合国',
    '制裁',
    '冲突',
  };
}
