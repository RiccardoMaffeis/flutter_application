import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application/features/shop/domain/product_details.dart';

import '../domain/products_repository.dart';
import '../domain/product.dart';
import '../domain/category.dart';

import 'dto/product_dto.dart';
import 'dto/product_dto_mapper.dart';

class ProductsRepositoryImpl implements ProductsRepository {
  final _rng = Random(1);
  final _favs = <String>{};

  static const List<Category> _cats = <Category>[
    Category(id: 'all', name: 'All'),
    Category(id: 'xt1', name: 'XT1'),
    Category(id: 'xt2', name: 'XT2'),
    Category(id: 'xt3', name: 'XT3'),
    Category(id: 'xt4', name: 'XT4'),
    Category(id: 'xt5', name: 'XT5'),
    Category(id: 'xt6', name: 'XT6'),
    Category(id: 'xt7', name: 'XT7'),
  ];

  List<Product>? _all;

  Future<void> _ensureLoaded() async {
    if (_all != null) return;

    final raw = await rootBundle.loadString('lib/json/XT1.json');
    final decoded = json.decode(raw);

    final List<Map<String, dynamic>> items;
    if (decoded is List) {
      items = decoded.cast<Map<String, dynamic>>();
    } else if (decoded is Map<String, dynamic>) {
      items = [decoded];
    } else {
      items = const [];
    }

    final seenCodes = <String>{};

    _all = items
        .map((m) => ProductDto.fromJson(m))
        .where((dto) => dto.code.isNotEmpty && seenCodes.add(dto.code))
        .map((dto) {
          final price = 100 + _rng.nextInt(200) + _rng.nextDouble();
          return dto.toDomain(price);
        })
        .toList();
  }

  @override
  Future<List<Category>> fetchCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _cats;
  }

  @override
  Future<List<Product>> fetchProducts({String? categoryId}) async {
    await _ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final all = _all ?? const <Product>[];

    if (categoryId == null || categoryId == 'all') return all;
    return all.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<Set<String>> fetchFavourites() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _favs;
  }

  @override
  Future<void> toggleFavourite(String productId) async {
    _favs.contains(productId) ? _favs.remove(productId) : _favs.add(productId);
  }

  @override
  Future<int> getCartCount() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return 2;
  }

  Future<List<Map<String, dynamic>>> _loadRawItems() async {
    final raw = await rootBundle.loadString('lib/json/XT1.json');
    final decoded = json.decode(raw);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    } else if (decoded is Map<String, dynamic>) {
      return [decoded];
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<ProductDetails> fetchProductDetails(String productId) async {
    // 1) assicura i Product in memoria (per avere price, image, category, ecc.)
    await _ensureLoaded();
    final all = _all ?? const <Product>[];
    final product = all.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Product not found: $productId'),
    );

    // 2) cerca il record grezzo nel JSON e prendi general.specs
    final items = await _loadRawItems();
    final raw = items.firstWhere(
      (m) => (m['code'] as String?)?.trim() == productId,
      orElse: () => const <String, dynamic>{},
    );

    final general = (raw['general'] as Map?)?.cast<String, dynamic>() ?? {};
    final specsRaw = (general['specs'] as Map?)?.cast<String, dynamic>() ?? {};

    // mappa tutto a String
    final specs = <String, String>{
      for (final e in specsRaw.entries) e.key: e.value?.toString() ?? '',
    };

    return ProductDetails(product: product, specs: specs);
  }
}
