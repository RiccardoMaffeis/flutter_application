class Product {
  final String id;
  final String code;       
  final String displayName;   
  final double price;
  final String imageUrl;
  final String categoryId;

  const Product({
    required this.id,
    required this.code,
    required this.displayName,     
    required this.price,
    required this.imageUrl,
    required this.categoryId,
  });
}
