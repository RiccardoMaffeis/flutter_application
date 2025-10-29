// Domain entity representing a catalog product (immutable).
// Notes:
// - `id`: stable unique identifier used across the app (often same as `code`).
// - `code`: manufacturer/SKU code, useful for lookups and deduplication.
// - `displayName`: human-readable name for UI.
// - `price`: unit price (numeric; currency handled by the UI layer).
// - `imageUrl`: asset or network image path for thumbnails/previews.
// - `categoryId`: foreign key linking to a Category.id (e.g., 'xt1', 'all').

class Product {
  final String id; // Stable unique ID.
  final String code; // Manufacturer/SKU code.
  final String displayName; // Display name for UI.
  final double price; // Unit price (no currency symbol).
  final String imageUrl; // Image asset/URL for the product.
  final String categoryId; // Category identifier reference.

  const Product({
    required this.id,
    required this.code,
    required this.displayName,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
  });
}
