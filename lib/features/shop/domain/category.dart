// Domain model for a product category.
// - `id`: stable identifier used for filtering/routing (e.g., 'xt1', 'all').
// - `name`: human-readable label shown in the UI (e.g., 'XT1').
// - `emoji`: optional decorative icon for display (can be null).
// Immutable by design; extend with equality/hash if needed by your state layer.

class Category {
  final String id;
  final String name;
  final String? emoji;

  const Category({required this.id, required this.name, this.emoji});
}
