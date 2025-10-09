class ARChoice {
  final String id; // es. "xt", "emax"
  final String title; // es. "Select an XT"
  final String asset; // path immagine
  final String route; // rotta di destinazione

  const ARChoice({
    required this.id,
    required this.title,
    required this.asset,
    required this.route,
  });
}
