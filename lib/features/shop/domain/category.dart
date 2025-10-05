class Category {
  final String id;
  final String name;
  final String? emoji; // per un’icona rapida nello chip

  const Category({required this.id, required this.name, this.emoji});
}
