import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/products_repository.dart';
import '../domain/product.dart';
import '../domain/category.dart';
import 'dto/product_dto.dart';
import 'dto/product_dto_mapper.dart';
import 'package:flutter_application/features/shop/domain/product_details.dart';

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

  /// Elenca tutti gli asset JSON sotto lib/json/ usando l'AssetManifest
  Future<List<String>> _listJsonAssets() async {
    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final dynamic manifest = json.decode(manifestStr);

    if (manifest is Map<String, dynamic>) {
      final paths =
          manifest.keys
              .where((k) => k.startsWith('lib/json/') && k.endsWith('.json'))
              .toList()
            ..sort();
      return paths;
    }
    // fallback se il manifest non è nel formato atteso
    return const ['lib/json/XT1.json'];
  }

  Future<void> _ensureLoaded() async {
    if (_all != null) return;

    final jsonPaths = await _listJsonAssets();
    final seenCodes = <String>{};
    final out = <Product>[];

    for (final path in jsonPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw);

      final List<Map<String, dynamic>> items;
      if (decoded is List) {
        items = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        items = [decoded];
      } else {
        continue;
      }

      for (final m in items) {
        final dto = ProductDto.fromJson(m);
        if (dto.code.isEmpty || !seenCodes.add(dto.code)) continue;

        final price = 100 + _rng.nextInt(200) + _rng.nextDouble();

        out.add(dto.toDomain(price));
      }
    }

    _all = out;
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
    final jsonPaths = await _listJsonAssets();
    final all = <Map<String, dynamic>>[];
    for (final path in jsonPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw);
      if (decoded is List) {
        all.addAll(decoded.cast<Map<String, dynamic>>());
      } else if (decoded is Map<String, dynamic>) {
        all.add(decoded.cast<String, dynamic>());
      }
    }
    return all;
  }

  @override
  Future<ProductDetails> fetchProductDetails(String productId) async {
    await _ensureLoaded();
    final allProducts = _all ?? const <Product>[];
    final product = allProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Product not found: $productId'),
    );

    final items = await _loadRawItems();
    final raw = items.firstWhere(
      (m) => (m['code'] as String?)?.trim() == productId,
      orElse: () => const <String, dynamic>{},
    );

    final general = (raw['general'] as Map?)?.cast<String, dynamic>() ?? {};
    final specsRaw = (general['specs'] as Map?)?.cast<String, dynamic>() ?? {};
    final specs = <String, String>{
      for (final e in specsRaw.entries) e.key: e.value?.toString() ?? '',
    };

    return ProductDetails(product: product, specs: specs);
  }
}
