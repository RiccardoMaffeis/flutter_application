// Maps a ProductDto (data layer) into a Product (domain layer) while
// inferring a category and selecting an image asset based on the name/code.
// Notes:
// - Category guessing uses the first "XT[1-7]" match in the product name.
// - Image selection prefers explicit "3P"/"4P" pole hints; falls back to 3P.

import '../../domain/product.dart';
import 'product_dto.dart';

extension ProductDtoMapper on ProductDto {
  // Convert DTO to domain model, taking a resolved price as parameter.
  Product toDomain(double price) {
    // Infer category id (e.g., xt1..xt7) from the raw name.
    final catId = _guessCategoryId(name);
    // Choose an illustrative image based on family + poles.
    final image = _pickImage(catId, name, code);

    return Product(
      id: code, // Use product code as stable id.
      code: code, // Keep raw code for display/lookup.
      displayName: name, // Human-readable name.
      price: price, // Injected/resolved price.
      imageUrl: image, // Asset path decided by _pickImage.
      categoryId: catId, // e.g., xt1..xt7 or 'all'.
    );
  }

  // Extracts "XT[1-7]" from the name and returns a normalized category id.
  // If no match is found, default to 'all'.
  String _guessCategoryId(String rawName) {
    final m = RegExp(r'XT([1-7])', caseSensitive: false).firstMatch(rawName);
    return m != null ? 'xt${m.group(1)!}' : 'all';
  }

  // Picks an image asset path using family (XT1..XT7) and pole info (3P/4P).
  // Strategy:
  // 1) Validate family; if not XT1..XT7, return a placeholder image.
  // 2) Build a compact uppercase token from "name + code" to match patterns.
  // 3) Prefer explicit "4P"/"3P" (optionally with "FF") in the compact token.
  // 4) Otherwise, detect poles via more permissive patterns on the uppercase string.
  // 5) Default to 3P if nothing is found.
  String _pickImage(String categoryId, String name, String code) {
    final fam = categoryId.toUpperCase();
    if (!RegExp(r'^XT[1-7]$').hasMatch(fam)) {
      return 'lib/images/placeholder.png';
    }

    // Normalize to uppercase and strip non-alphanumeric chars for compact matching.
    final up = ('$name $code').toUpperCase();
    final compact = up.replaceAll(RegExp(r'[^A-Z0-9]+'), '');

    // Strong match on compact token: look for 4P (optionally followed by FF).
    if (RegExp(r'4P(F{0,2})?').hasMatch(compact)) {
      return 'lib/images/$fam/${fam}_4p.png';
    }
    // Strong match for 3P (optionally followed by FF).
    if (RegExp(r'3P(F{0,2})?').hasMatch(compact)) {
      return 'lib/images/$fam/${fam}_3p.png';
    }

    // Fallback: more permissive matches on the spaced/uppercase string.
    final has4 = RegExp(r'4P(?:\s*F\s*F)?').hasMatch(up);
    final has3 = RegExp(r'3P(?:\s*F\s*F)?').hasMatch(up);
    final poles = has4 ? '4p' : (has3 ? '3p' : '3p');

    return 'lib/images/$fam/${fam}_$poles.png';
  }
}
