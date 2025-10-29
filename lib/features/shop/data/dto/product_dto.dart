// Lightweight DTO representing a product scraped/parsed from JSON.
// Fields:
// - code: unique product identifier (as provided by source).
// - name: human-readable product name.
// - url: optional link to the product page.
// - family: inferred family (e.g., "XT1".."XT7") or "Other" if unknown.
// - variant: optional variant letter (currently extracted only for XT1X pattern).
// - poles: number of poles, inferred as 4 if "4P" present, otherwise 3.

class ProductDto {
  final String code;
  final String name;
  final String? url;

  final String family;
  final String? variant;
  final int poles;

  ProductDto({
    required this.code,
    required this.name,
    required this.url,
    required this.family,
    required this.variant,
    required this.poles,
  });

  // Factory parser from a loosely-typed JSON map.
  // Parsing strategy:
  // 1) Normalize/trim `code` and `name`.
  // 2) Derive `family` by matching "XT\d+" within the uppercase name.
  // 3) Optionally extract a variant letter for XT1 (pattern: XT1[A-Z]).
  // 4) Infer `poles`: if "4P" appears in the name → 4, else fallback to 3.
  factory ProductDto.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';
    final url = json['url'] as String?;

    final up = name.toUpperCase();
    final famMatch = RegExp(r'\bXT(\d+)\b').firstMatch(up);
    final family = famMatch != null ? 'XT${famMatch.group(1)!}' : 'Other';

    final variant = RegExp(r'\bXT1([A-Z])\b').firstMatch(up)?.group(1);
    final poles = up.contains('4P') ? 4 : 3;

    return ProductDto(
      code: code,
      name: name,
      url: url,
      family: family,
      variant: variant,
      poles: poles,
    );
  }
}
