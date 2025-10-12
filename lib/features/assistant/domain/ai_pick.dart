class DeviceCandidate {
  final String id;       // usa l'ID che hai in app (Product.id o simile)
  final String code;     // es. "XT3_4p"
  final String label;    // es. "XT3 4 poli"
  final List<String> tags; // es. ["3p", "4p", "XT3", "interruttore"]

  const DeviceCandidate({
    required this.id,
    required this.code,
    required this.label,
    this.tags = const [],
  });

  @override
  String toString() =>
      '[$id] $code | $label | tags=${tags.join(",")}';
}

class AiPickResult {
  final List<String> picks; // lista di ID scelti (presenti in candidates)
  final String reason;      // spiegazione testuale breve
  const AiPickResult({required this.picks, required this.reason});
}
