import '../../domain/product.dart';
import 'product_dto.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain(double price) {
    final catId = _guessCategoryId(name);
    final image = _pickImage(catId, name);

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

  String _pickImage(String categoryId, String name) {
    if (categoryId == 'xt1') {
      final lower = name.toLowerCase();
      if (lower.contains('4p')) {
        return 'lib/images/XT1/9IBA255356_800x536.png';
      }
      return 'lib/images/XT1/9IBA255127_800x536.png';
    }
    return 'lib/images/placeholder.png';
  }
}
