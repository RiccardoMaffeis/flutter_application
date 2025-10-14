class DeviceCandidate {
  final String id;
  final String code; 
  final String label;
  final List<String> tags;

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
  final List<String> picks;
  final String reason;
  const AiPickResult({required this.picks, required this.reason});
}
