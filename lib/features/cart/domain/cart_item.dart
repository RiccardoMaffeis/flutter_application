class CartItem {
  final String productId;
  final String code;
  final String displayName;
  final String imageUrl;
  final double unitPrice;
  final int qty;

  const CartItem({
    required this.productId,
    required this.code,
    required this.displayName,
    required this.imageUrl,
    required this.unitPrice,
    required this.qty,
  });

  double get lineTotal => unitPrice * qty;

  CartItem copyWith({int? qty, double? unitPrice}) => CartItem(
        productId: productId,
        code: code,
        displayName: displayName,
        imageUrl: imageUrl,
        unitPrice: unitPrice ?? this.unitPrice,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'code': code,
        'displayName': displayName,
        'imageUrl': imageUrl,
        'unitPrice': unitPrice,
        'qty': qty,
      };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        productId: m['productId'] as String,
        code: m['code'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        unitPrice: (m['unitPrice'] as num).toDouble(),
        qty: (m['qty'] as num).toInt(),
      );
}
