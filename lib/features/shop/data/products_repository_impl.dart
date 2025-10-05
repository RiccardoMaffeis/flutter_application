import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/products_repository.dart';
import '../domain/product.dart';
import '../domain/category.dart';

class ProductsRepositoryFake implements ProductsRepository {
  final _rng = Random(1);
  final _favs = <String>{};

  // Categorie allineate alle etichette mostrate in UI
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
        .map<Product?>((m) {
          final code = (m['code'] as String?)?.trim();
          if (code == null || code.isEmpty) return null;
          if (!seenCodes.add(code)) return null;

          final nameField = (m['name'] as String?) ?? '';

          final categoryId = _guessCategoryId(nameField);

          final price = 100 + _rng.nextInt(200) + _rng.nextDouble();

          final imagePath = _pickXt1Image(nameField);

          return Product(
            id: code,
            code: code, 
            displayName: nameField, 
            price: price,
            imageUrl: imagePath,
            categoryId: categoryId,
          );
        })
        .whereType<Product>()
        .toList();
  }

  String _guessCategoryId(String rawName) {
    final n = rawName.toUpperCase();
    if (n.contains('XT1')) return 'xt1';
    if (n.contains('XT2')) return 'xt2';
    if (n.contains('XT3')) return 'xt3';
    if (n.contains('XT4')) return 'xt4';
    if (n.contains('XT5')) return 'xt5';
    if (n.contains('XT6')) return 'xt6';
    if (n.contains('XT7')) return 'xt7';
    return 'all';
  }

  String _pickXt1Image(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('4p')) {
      return 'lib/images/XT1/9IBA255356_800x536.png';
    }
    return 'lib/images/XT1/9IBA255127_800x536.png';
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
    if (_favs.contains(productId)) {
      _favs.remove(productId);
    } else {
      _favs.add(productId);
    }
  }

  @override
  Future<int> getCartCount() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return 2; 
  }
}
