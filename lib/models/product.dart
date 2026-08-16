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
  final Map<String, int> stockVariants; // {'S': 10, 'M': 5} — مخزون حسب المقاس
  final int stockQuantity;           // كمية المخزون الكلية
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isNewArrival;
  final bool hasDiscount;
  final int discountPercentage;

  /// خيارات العرض — خريطة أعلام العرض (eid/winter/new/offers/limited)
  final Map<String, bool> displayOptions;
  final List<String> tags;
  final String brand;
  final String material;
  final String careInstructions;
  final String videoUrl;             // رابط فيديو المنتج (ريلز/اكتشف)
  final List<String> linkedOutfitIds; // معرفات منتجات الإطلالة المنسقة يدوياً (اختياري)
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
    this.stockVariants = const {},   // {'S': 10, 'M': 5} — مخزون حسب المقاس
    this.stockQuantity = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.isNewArrival = false,
    this.hasDiscount = false,
    this.discountPercentage = 0,
    this.displayOptions = const {},
    this.tags = const [],
    this.brand = 'ALAFIF NEWFORM',
    this.material = '',
    this.careInstructions = '',
    this.videoUrl = '',              // رابط فيديو المنتج (ريلز/اكتشف)
    this.linkedOutfitIds = const [],
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
      stockVariants: Map<String, int>.from(map['stockVariants'] ?? {}),
      stockQuantity: (map['stockQuantity'] ?? 0),
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      isNewArrival: map['isNewArrival'] ?? false,
      hasDiscount: map['hasDiscount'] ?? false,
      discountPercentage: map['discountPercentage'] ?? 0,
      displayOptions: map['displayOptions'] != null
          ? Map<String, bool>.from(map['displayOptions'] as Map)
          : const {},
      tags: List<String>.from(map['tags'] ?? []),
      brand: map['brand'] ?? 'ALAFIF NEWFORM',
      material: map['material'] ?? '',
      careInstructions: map['careInstructions'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      linkedOutfitIds: List<String>.from(map['linkedOutfitIds'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
    );
  }

  // ================= خيارات العرض =================

  /// ملابس العيد
  bool get isEidCollection => displayOptions['eid'] ?? false;

  /// ملابس الشتاء
  bool get isWinterCollection => displayOptions['winter'] ?? false;

  /// جديد العفيف نيوفورم
  bool get isNewAlafif => displayOptions['new'] ?? false;

  /// عروض وتخفيضات
  bool get isSpecialOffer => displayOptions['offers'] ?? false;

  /// كمية محدودة
  bool get isLimitedQuantity => displayOptions['limited'] ?? false;

  /// قائمة شارات العرض النشطة (نص + لون) لبطاقة المنتج
  List<({String label, String color})> get activeDisplayBadges {
    final badges = <({String label, String color})>[];
    if (isEidCollection) badges.add((label: 'عيد', color: '#7B1FA2'));
    if (isWinterCollection) badges.add((label: 'شتاء', color: '#1565C0'));
    if (isNewAlafif) badges.add((label: 'جديد', color: '#00838F'));
    if (isSpecialOffer) badges.add((label: 'عرض', color: '#E65100'));
    if (isLimitedQuantity) badges.add((label: 'كمية محدودة', color: '#C62828'));
    return badges;
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
      'stockVariants': stockVariants,
      'stockQuantity': stockQuantity,
      'rating': rating,
      'reviewCount': reviewCount,
      'isFeatured': isFeatured,
      'isNewArrival': isNewArrival,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'displayOptions': displayOptions,
      'tags': tags,
      'brand': brand,
      'material': material,
      'careInstructions': careInstructions,
      'videoUrl': videoUrl,
      'linkedOutfitIds': linkedOutfitIds,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
