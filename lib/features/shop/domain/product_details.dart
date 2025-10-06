import 'product.dart';

class ProductDetails {
  final Product product;
  final Map<String, String> specs;

  const ProductDetails({
    required this.product,
    required this.specs,
  });
}
