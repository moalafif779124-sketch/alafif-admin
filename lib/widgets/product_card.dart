import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import 'app_image.dart';

/// بطاقة عرض المنتج — مع شارات، ألوان، زر إضافة سريع
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final imgHeight = compact ? 140.0 : 180.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========== الصورة ===========
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  Hero(
                    tag: 'product_${product.id}',
                    child: AppImage(
                      imageUrl: product.images.isNotEmpty ? product.images.first : '',
                      height: imgHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      backgroundColor: AppColors.accentLight,
                      cacheWidth: 300,
                    ),
                  ),
                  // شارات
                  if (product.hasDiscount)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (product.isNewArrival && !compact)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('جديد', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // شارة المخزون المحدود
                  if (product.stockQuantity > 0 && product.stockQuantity < 5)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${product.stockQuantity} متبقي',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // زر المفضلة
                  Positioned(
                    top: 6, left: 6,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlist, _) {
                        final isFav = wishlist.isWishlisted(product.id);
                        return GestureDetector(
                          onTap: () => wishlist.toggleWishlist(product.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isFav ? Colors.red : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // =========== التفاصيل ===========
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // التقييم
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: AppColors.rating),
                      const SizedBox(width: 3),
                      Text('${product.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      if (product.reviewCount > 0)
                        Text(' (${product.reviewCount})',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const Spacer(),
                      // شارة الأكثر مبيعاً
                      if (product.reviewCount > 20)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('الأكثر مبيعاً',
                              style: TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ألوان المنتج (نقاط)
                  if (product.colorOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: product.colorOptions.take(4).map((c) {
                          final hex = c['hex'] ?? '#000000';
                          final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                          return Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // السعر + زر الإضافة
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary,
                              ),
                            ),
                            if (product.hasOldPrice)
                              Text(
                                '${product.oldPrice!.toStringAsFixed(0)} ${AppConstants.currency}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // زر الإضافة السريعة
                      Consumer<CartProvider>(
                        builder: (context, cart, _) {
                          final inCart = cart.items.any((i) => i.product.id == product.id);
                          return GestureDetector(
                            onTap: inCart
                                ? null
                                : () {
                                    cart.addItem(CartItem(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      product: product,
                                      size: product.sizes.isNotEmpty ? product.sizes.first : '',
                                      color: '',
                                      quantity: 1,
                                    ));
                                  },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: inCart
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                inCart ? Icons.check : Icons.add_shopping_cart,
                                size: 16,
                                color: inCart ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
