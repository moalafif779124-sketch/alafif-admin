import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/banner.dart';
import '../config/constants.dart';
import 'app_image.dart';

/// عنصر عرض البانر في الكاروسيل
class BannerItem extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback? onTap;

  const BannerItem({
    super.key,
    required this.banner,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // صورة الخلفية
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AppImage(
              imageUrl: banner.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              backgroundColor: AppColors.primary,
            ),
          ),
          // طبقة التدرج فوق الصورة
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  AppColors.primary.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // النص
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      banner.buttonText,
                      style: const TextStyle(
                        color: AppColors.textOnAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
