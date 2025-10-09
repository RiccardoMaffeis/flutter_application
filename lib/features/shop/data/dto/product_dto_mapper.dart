import '../../domain/product.dart';
import 'product_dto.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain(double price) {
    final catId = _guessCategoryId(name);
    final image = _pickImage(catId, name, code);

    return Product(
      id: code,
      code: code,
      displayName: name,
      price: price,
      imageUrl: image,
      categoryId: catId,
    );
  }

  String _guessCategoryId(String rawName) {
    final m = RegExp(r'XT([1-7])', caseSensitive: false).firstMatch(rawName);
    return m != null ? 'xt${m.group(1)!}' : 'all';
  }

  String _pickImage(String categoryId, String name, String code) {
    final fam = categoryId.toUpperCase();
    if (!RegExp(r'^XT[1-7]$').hasMatch(fam)) {
      return 'lib/images/placeholder.png';
    }

    final up = ('$name $code').toUpperCase();
    final compact = up.replaceAll(
      RegExp(r'[^A-Z0-9]+'),
      '',
    );

    if (RegExp(r'4P(F{0,2})?').hasMatch(compact)) {
      return 'lib/images/$fam/${fam}_4p.png';
    }
    if (RegExp(r'3P(F{0,2})?').hasMatch(compact)) {
      return 'lib/images/$fam/${fam}_3p.png';
    }

    final has4 = RegExp(r'4P(?:\s*F\s*F)?').hasMatch(up);
    final has3 = RegExp(r'3P(?:\s*F\s*F)?').hasMatch(up);
    final poles = has4 ? '4p' : (has3 ? '3p' : '3p');

    return 'lib/images/$fam/${fam}_$poles.png';
  }
}
