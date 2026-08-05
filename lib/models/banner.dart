/// نموذج الإعلان/البنر الرئيسي
class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? productId;
  final String? categoryId;
  final String buttonText;
  final bool isActive;
  final int order;

  BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.imageUrl,
    this.productId,
    this.categoryId,
    this.buttonText = 'تسوق الآن',
    this.isActive = true,
    this.order = 0,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      productId: map['productId'],
      categoryId: map['categoryId'],
      buttonText: map['buttonText'] ?? 'تسوق الآن',
      isActive: map['isActive'] ?? true,
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'productId': productId,
      'categoryId': categoryId,
      'buttonText': buttonText,
      'isActive': isActive,
      'order': order,
    };
  }
}
