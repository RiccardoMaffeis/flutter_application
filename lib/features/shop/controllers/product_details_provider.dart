// features/shop/controllers/product_details_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product_details.dart';
import 'shop_controller.dart'; // per productsRepositoryProvider

/// Family: fornisci l'id (code) del prodotto
final productDetailsProvider = FutureProvider.family<ProductDetails, String>((
  ref,
  productId,
) async {
  final repo = ref.read(productsRepositoryProvider);
  return repo.fetchProductDetails(productId);
});
