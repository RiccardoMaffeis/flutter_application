class AiSource {
  final int idx; 
  final String title;
  final int page;
  final String url;

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
