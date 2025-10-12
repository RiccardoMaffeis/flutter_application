/// Immutable model representing a single AR entry choice displayed on the
/// AR landing screen. Each choice includes a stable id, a title to show in UI,
/// a preview asset path, and a navigation route to push when selected.
class ARChoice {
  /// Stable identifier for analytics, state keys, or routing decisions.
  final String id;

  /// Human-readable label shown to the user (e.g., "Select an XT").
  final String title;

  /// Path to the preview image asset rendered in the choice tile.
  final String asset;

  /// App route to navigate to when this choice is selected.
  final String route;

  /// Const constructor to allow compile-time constants and value reuse.
  const ARChoice({
    required this.id,
    required this.title,
    required this.asset,
    required this.route,
  });
}
