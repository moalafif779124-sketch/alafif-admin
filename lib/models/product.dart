/// نموذج المنتج
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final String categoryId;
  final String categoryName;
  final List<String> images;
  final List<String> sizes;          // مقاسات قياسية (M, L, XL, 52, 54...)
  final String sizeRange;            // نطاق مقاس (1-60)
  final List<String> colors;         // أكواد الألوان hex
  final List<Map<String, String>> colorOptions; // {name, hex}
  final Map<String, int> stock;      // {'size_color': quantity}
  final int stockQuantity;           // كمية المخزون الكلية
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isNewArrival;
  final bool hasDiscount;
  final int discountPercentage;
  final List<String> tags;
  final String brand;
  final String material;
  final String careInstructions;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.categoryId,
    required this.categoryName,
    required this.images,
    required this.sizes,
    this.sizeRange = '',
    required this.colors,
    this.colorOptions = const [],
    this.stock = const {},
    this.stockQuantity = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.isNewArrival = false,
    this.hasDiscount = false,
    this.discountPercentage = 0,
    this.tags = const [],
    this.brand = 'ALAFIF NEWFORM',
    this.material = '',
    this.careInstructions = '',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get effectivePrice => oldPrice ?? price;

  bool get hasOldPrice => oldPrice != null && oldPrice! > price;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      oldPrice: map['oldPrice']?.toDouble(),
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      sizes: List<String>.from(map['sizes'] ?? []),
      sizeRange: map['sizeRange'] ?? '',
      colors: List<String>.from(map['colors'] ?? []),
      colorOptions: (map['colorOptions'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      stock: Map<String, int>.from(map['stock'] ?? {}),
      stockQuantity: (map['stockQuantity'] ?? 0),
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      isNewArrival: map['isNewArrival'] ?? false,
      hasDiscount: map['hasDiscount'] ?? false,
      discountPercentage: map['discountPercentage'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      brand: map['brand'] ?? 'ALAFIF NEWFORM',
      material: map['material'] ?? '',
      careInstructions: map['careInstructions'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'oldPrice': oldPrice,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'images': images,
      'sizes': sizes,
      'sizeRange': sizeRange,
      'colors': colors,
      'colorOptions': colorOptions,
      'stock': stock,
      'stockQuantity': stockQuantity,
      'rating': rating,
      'reviewCount': reviewCount,
      'isFeatured': isFeatured,
      'isNewArrival': isNewArrival,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'tags': tags,
      'brand': brand,
      'material': material,
      'careInstructions': careInstructions,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
