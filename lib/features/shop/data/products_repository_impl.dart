// Concrete implementation of ProductsRepository that loads product data
// from bundled JSON assets (via AssetManifest), parses/normalizes prices,
// maps DTOs to domain models, and provides simple in-memory stubs for
// favourites and cart count.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/products_repository.dart';
import '../domain/product.dart';
import '../domain/category.dart';
import 'dto/product_dto.dart';
import 'dto/product_dto_mapper.dart';
import 'package:flutter_application/features/shop/domain/product_details.dart';

class ProductsRepositoryImpl implements ProductsRepository {
  // Local, in-memory favourites set (stub for a real backend).
  final _favs = <String>{};

  // Static list of supported categories (XT1..XT7 + All).
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

  // Cached domain products; populated on first load.
  List<Product>? _all;

  // Scans the Flutter AssetManifest for JSON files under lib/json/*.json.
  // Falls back to a default path if manifest shape is unexpected.
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
    return const ['lib/json/XT1.json'];
  }

  // Robust price parser handling various formats:
  // - numeric types directly
  // - strings with currency symbols and thousand/decimal separators
  // Heuristic:
  // - If both commas and dots appear → assume dot as thousand sep, comma as decimal
  // - If only a single comma appears → treat it as decimal
  // - Else defer to double.tryParse
  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    final s0 = value.toString().trim();
    if (s0.isEmpty) return 0.0;

    // Strip everything except digits, comma, dot.
    String s = s0.replaceAll(RegExp(r'[^\d,\.]'), '');

    final commas = RegExp(',').allMatches(s).length;
    final dots = RegExp(r'\.').allMatches(s).length;

    if (commas > 0 && dots > 0) {
      // Example: "1.234,56" → "1234.56"
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    } else if (commas == 1 && dots == 0) {
      // Example: "123,45" → "123.45"
      s = s.replaceAll(',', '.');
    } else {
      // Examples already compatible with double parsing.
    }

    return double.tryParse(s) ?? 0.0;
  }

  // Attempts to extract a price field from a flexible JSON shape.
  // Looks under general.specs.price, general.price, or top-level price.
  double _extractPrice(Map<String, dynamic> m) {
    final general = (m['general'] is Map)
        ? (m['general'] as Map).cast<String, dynamic>()
        : null;
    final specs = (general != null && general['specs'] is Map)
        ? (general['specs'] as Map).cast<String, dynamic>()
        : null;

    final raw = specs?['price'] ?? general?['price'] ?? m['price'];
    return _parsePrice(raw);
  }

  // Lazy-loads and caches all products:
  // - enumerates JSON assets
  // - decodes each file (list or single map)
  // - builds ProductDto, deduplicates by code, resolves price, maps to domain
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

        final price = _extractPrice(m);
        out.add(dto.toDomain(price));
      }
    }

    _all = out;
  }

  @override
  Future<List<Category>> fetchCategories() async {
    // Simulated latency for a smoother UX.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _cats;
  }

  @override
  Future<List<Product>> fetchProducts({String? categoryId}) async {
    await _ensureLoaded();
    // Simulated latency (e.g., network).
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final all = _all ?? const <Product>[];
    if (categoryId == null || categoryId == 'all') return all;
    return all.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<Set<String>> fetchFavourites() async {
    // Simulated latency; returns the in-memory set.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _favs;
  }

  @override
  Future<void> toggleFavourite(String productId) async {
    // In-memory toggle (placeholder for a persistent backend).
    _favs.contains(productId) ? _favs.remove(productId) : _favs.add(productId);
  }

  @override
  Future<int> getCartCount() async {
    // Stubbed cart count with slight delay.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return 2;
  }

  // Loads all raw JSON maps from discovered asset files, preserving the
  // original structure for fields not present in the domain model.
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

    // Find the already-mapped domain product or error if not found.
    final allProducts = _all ?? const <Product>[];
    final product = allProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Product not found: $productId'),
    );

    // Retrieve the raw JSON map to extract specs as key/value strings.
    final items = await _loadRawItems();
    final raw = items.firstWhere(
      (m) => (m['code'] as String?)?.trim() == productId,
      orElse: () => const <String, dynamic>{},
    );

    // Extract nested "general.specs" map as strings; default to empty.
    final general = (raw['general'] as Map?)?.cast<String, dynamic>() ?? {};
    final specsRaw = (general['specs'] as Map?)?.cast<String, dynamic>() ?? {};
    final specs = <String, String>{
      for (final e in specsRaw.entries) e.key: e.value?.toString() ?? '',
    };

    return ProductDetails(product: product, specs: specs);
  }
}
