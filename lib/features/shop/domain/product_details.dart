// Aggregate domain model representing detailed information for a product.
// - `product`: the base domain entity (id, name, price, etc.).
// - `specs`: a normalized key→value map of technical specifications,
//            ready for display (e.g., in a details screen).
// Immutable; extend with helpers (e.g., copyWith) if mutation is needed.

import 'product.dart';

class ProductDetails {
  // The core product entity.
  final Product product;
  // Flattened specs as human-readable strings.
  final Map<String, String> specs;

  const ProductDetails({required this.product, required this.specs});
}
