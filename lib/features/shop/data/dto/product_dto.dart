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
