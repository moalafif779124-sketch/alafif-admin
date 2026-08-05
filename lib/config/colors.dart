import 'package:flutter/material.dart';

/// الألوان الرئيسية للعلامة التجارية "العفيف نيوفورم"
/// مستوحاة من درع الشعار: أزرق بحري غامق + فضي معدني
class AppColors {
  AppColors._();

  // =========== الألوان الأساسية ===========
  /// الأزرق البحري الغامق - اللون الرئيسي (من خلفية الدرع)
  static const Color primary = Color(0xFF0D1B3E);
  static const Color primaryLight = Color(0xFF1A2D5E);
  static const Color primaryDark = Color(0xFF070E24);

  /// الفضي المعدني - لون ثانوي (من تفاصيل الشعار)
  static const Color accent = Color(0xFFC0C0C0);
  static const Color accentLight = Color(0xFFE8E8E8);
  static const Color accentDark = Color(0xFF8A8A8A);

  // =========== ألوان الخلفية ===========
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // =========== ألوان النصوص ===========
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1A1A2E);

  // =========== ألوان الحالة ===========
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // =========== الحدود والفواصل ===========
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F0F0);

  // =========== ألوان المنتجات ===========
  static const Color discount = Color(0xFFEF4444);
  static const Color favorite = Color(0xFFEF4444);
  static const Color rating = Color(0xFFF59E0B);

  // =========== ألوان الخلفيات المتدرجة ===========
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  // =========== الظلال ===========
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
