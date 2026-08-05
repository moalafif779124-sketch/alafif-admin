/// نموذج فئة المنتج
class Category {
  final String id;
  final String name;
  final String nameEn;
  final String icon;
  final String? imageUrl;
  final int productCount;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.icon,
    this.imageUrl,
    this.productCount = 0,
    this.isActive = true,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameEn: map['nameEn'] ?? '',
      icon: map['icon'] ?? '',
      imageUrl: map['imageUrl'],
      productCount: map['productCount'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'icon': icon,
      'imageUrl': imageUrl,
      'productCount': productCount,
      'isActive': isActive,
    };
  }
}
