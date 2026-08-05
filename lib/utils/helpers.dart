import 'package:flutter/material.dart';
import '../config/colors.dart';

/// دوال مساعدة للتنسيق والعرض
class Helpers {
  /// تنسيق السعر بالعملة المحلية
  static String formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '${price.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      )} ﷼';
    }
    return '${price.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    )} ﷼';
  }

  /// تنسيق التاريخ
  static String formatDate(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// تنسيق التاريخ مع الوقت
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// الحصول على أيقونة التصنيف
  static IconData getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'shamzan':
        return Icons.checkroom;
      case 'fanail':
        return Icons.style;
      case 'aqwat':
        return Icons.watch;
      case 'pajamas':
        return Icons.bed;
      case 'belts':
        return Icons.sell;
      case 'jackets':
        return Icons.fitbit;
      case 'underwear':
        return Icons.face;
      case 'mawaz':
        return Icons.accessibility_new;
      default:
        return Icons.shopping_bag;
    }
  }

  /// لون حالة الطلب
  static Color getOrderStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B); // برتقالي
      case 'confirmed':
        return const Color(0xFF3B82F6); // أزرق
      case 'processing':
        return const Color(0xFFF59E0B); // كهرماني
      case 'shipped':
        return const Color(0xFF8B5CF6); // بنفسجي
      case 'delivered':
        return AppColors.success; // أخضر
      case 'cancelled':
        return AppColors.error; // أحمر
      default:
        return AppColors.textSecondary;
    }
  }

  /// أيقونة حالة الطلب
  static IconData getOrderStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.inventory_2;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  /// أيقونة طريقة الدفع
  static IconData getPaymentIcon(String method) {
    switch (method) {
      case 'kuraimi':
        return Icons.account_balance_wallet;
      case 'jeeb':
        return Icons.credit_card;
      case 'cod':
        return Icons.monetization_on;
      default:
        return Icons.payments;
    }
  }

  /// اسم طريقة الدفع
  static String getPaymentName(String method) {
    switch (method) {
      case 'kuraimi':
        return 'كريمي باي';
      case 'jeeb':
        return 'جيب';
      case 'cod':
        return 'الدفع عند الاستلام';
      default:
        return method;
    }
  }

  /// تحويل اللون من Hex إلى Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}
