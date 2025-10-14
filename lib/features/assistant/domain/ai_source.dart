// features/assistant/domain/ai_source.dart
class AiSource {
  final int idx;       // [1], [2], ...
  final String title;  // titolo documento
  final int page;      // pagina (1-based)
  final String url;    // URL GCS/https del PDF

  const AiSource({required this.idx, required this.title, required this.page, required this.url});

  Map<String, dynamic> toJson() => {
    'idx': idx,
    'title': title,
    'page': page,
    'url': url,
  };

  factory AiSource.fromJson(Map<String, dynamic> j) =>
      AiSource(idx: j['idx'], title: j['title'], page: j['page'], url: j['url']);
}
