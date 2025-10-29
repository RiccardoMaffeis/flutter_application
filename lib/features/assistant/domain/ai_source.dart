// Value object representing a single citation / provenance entry for an AI reply.
// Typical use: display source title + page and open the `url` for verification.

class AiSource {
  // Index within the list of sources returned by the backend (stable ordering).
  final int idx;

  // Human-readable source title (e.g., document name or web page title).
  final String title;

  // Page number within the source (use 1-based indexing if applicable).
  final int page;

  // Direct link to the source material (web URL or deep link).
  final String url;

  // Immutable constructor requiring all fields.
  const AiSource({
    required this.idx,
    required this.title,
    required this.page,
    required this.url,
  });

  // Serialize to a JSON-friendly map (useful for persistence or transport).
  Map<String, dynamic> toJson() => {
    'idx': idx,
    'title': title,
    'page': page,
    'url': url,
  };

  // Factory to build an AiSource from a decoded JSON map.
  factory AiSource.fromJson(Map<String, dynamic> j) => AiSource(
    idx: j['idx'] as int,
    title: j['title'] as String,
    page: j['page'] as int,
    url: j['url'] as String,
  );
}
