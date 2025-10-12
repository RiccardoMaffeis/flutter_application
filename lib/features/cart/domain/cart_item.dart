/// Immutable value object representing a line item in the shopping cart.
/// Includes product identifiers, display metadata, pricing and quantity.
/// Provides helpers for line total calculation, copying, and (de)serialization.
class CartItem {
  /// Stable product identifier (primary key for cart operations).
  final String productId;

  /// Human-readable or ERP/SKU code of the product.
  final String code;

  /// Name shown in the UI (e.g., list tiles, cart summary).
  final String displayName;

  /// URL or asset path of the product image.
  final String imageUrl;

  /// Unit price for a single quantity of the product.
  final double unitPrice;

  /// Quantity of this product in the cart (must be >= 0).
  final int qty;

  /// Constructs a cart item with all required fields.
  const CartItem({
    required this.productId,
    required this.code,
    required this.displayName,
    required this.imageUrl,
    required this.unitPrice,
    required this.qty,
  });

  /// Convenience getter for the line amount: unitPrice * qty.
  double get lineTotal => unitPrice * qty;

  /// Returns a new instance with selectively overridden fields.
  /// Useful for immutability-friendly updates (e.g., changing qty or price).
  CartItem copyWith({int? qty, double? unitPrice}) => CartItem(
    productId: productId,
    code: code,
    displayName: displayName,
    imageUrl: imageUrl,
    unitPrice: unitPrice ?? this.unitPrice,
    qty: qty ?? this.qty,
  );

  /// Serializes this object into a JSON-serializable map.
  /// Compatible with local storage and Firestore documents.
  Map<String, dynamic> toMap() => {
    'productId': productId,
    'code': code,
    'displayName': displayName,
    'imageUrl': imageUrl,
    'unitPrice': unitPrice,
    'qty': qty,
  };

  /// Factory constructor that builds a CartItem from a decoded map.
  /// Performs safe casts for numeric fields to handle int/double inputs.
  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    productId: m['productId'] as String,
    code: m['code'] as String? ?? '',
    displayName: m['displayName'] as String? ?? '',
    imageUrl: m['imageUrl'] as String? ?? '',
    unitPrice: (m['unitPrice'] as num).toDouble(),
    qty: (m['qty'] as num).toInt(),
  );
}
