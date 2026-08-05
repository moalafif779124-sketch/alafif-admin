/// إعدادات التوصيل الإقليمي — أسعار الشحن حسب المحافظة
class DeliveryConfig {
  DeliveryConfig._();

  /// عتبة الشحن المجاني: توصيل مجاني للمجموع ≥ 50,000 ريال
  static const double freeShippingThreshold = 50000;

  /// قائمة المحافظات مع أسعار التوصيل (بالريال اليمني)
  static const List<Map<String, dynamic>> cities = [
    {'id': 'sanaa', 'name': 'صنعاء', 'shippingCost': 2000},
    {'id': 'ibb', 'name': 'إب', 'shippingCost': 1500},
    {'id': 'aden', 'name': 'عدن', 'shippingCost': 3000},
    {'id': 'taiz', 'name': 'تعز', 'shippingCost': 2500},
    {'id': 'other', 'name': 'بقية المحافظات', 'shippingCost': 3500},
  ];

  /// معرف محافظة افتراضي
  static const String defaultCityId = 'sanaa';

  /// حساب تكلفة التوصيل حسب المحافظة (صفر عند تجاوز عتبة الشحن المجاني)
  static double getShippingCost(String? cityId, {double subtotal = 0}) {
    // شحن مجاني للطلبات الكبيرة
    if (subtotal >= freeShippingThreshold) return 0;

    final cityIdSafe = (cityId == null || cityId.isEmpty) ? defaultCityId : cityId;
    for (final city in cities) {
      if (city['id'] == cityIdSafe) {
        return (city['shippingCost'] as num).toDouble();
      }
    }
    // الافتراضي: بقية المحافظات
    return 3500;
  }

  /// اسم المحافظة من المعرف
  static String cityName(String? cityId) {
    final cityIdSafe = (cityId == null || cityId.isEmpty) ? defaultCityId : cityId;
    for (final city in cities) {
      if (city['id'] == cityIdSafe) {
        return city['name'] as String;
      }
    }
    return 'بقية المحافظات';
  }
}
