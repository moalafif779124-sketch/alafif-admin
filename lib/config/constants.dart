/// الثوابت العامة للتطبيق
class AppConstants {
  AppConstants._();

  // =========== معلومات التطبيق ===========
  static const String appName = 'العفيف نيوفورم';
  static const String appNameEn = 'ALAFIF NEWFORM';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'الأناقة الرجالية الفاخرة';

  // =========== معلومات المتجر ===========
  static const String companyName = 'العفيف نيوفورم للملابس الرجالية';
  static const String companyPhone = '+967123456789';
  static const String companyEmail = 'info@alafif-newform.com';
  static const String companyAddress = 'صنعاء، اليمن';
  static const String companyWhatsApp = 'https://wa.me/967784753557'; // 00967784753557

  // =========== فئات المنتجات ===========
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'shamzan',
      'name': 'شمزان',
      'nameEn': 'Shamzan',
      'icon': 'shamzan',
    },
    {
      'id': 'fanail',
      'name': 'فنايل',
      'nameEn': 'T-Shirts',
      'icon': 'fanail',
    },
    {
      'id': 'aqwat',
      'name': 'اكوات',
      'nameEn': 'Aqwat',
      'icon': 'aqwat',
    },
    {
      'id': 'pajamas',
      'name': 'بجائم',
      'nameEn': 'Pajamas',
      'icon': 'pajamas',
    },
    {
      'id': 'belts',
      'name': 'حزامات',
      'nameEn': 'Belts',
      'icon': 'belts',
    },
    {
      'id': 'jackets',
      'name': 'جاكتات',
      'nameEn': 'Jackets',
      'icon': 'jackets',
    },
    {
      'id': 'underwear',
      'name': 'ملابس داخليه',
      'nameEn': 'Underwear',
      'icon': 'underwear',
    },
    {
      'id': 'mawaz',
      'name': 'معاوز',
      'nameEn': 'Mawaz',
      'icon': 'mawaz',
    },
  ];

  // =========== خيارات المقاسات ===========
  static const List<String> allSizes = [
    'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL', '5XL', '6XL',
  ];
  static const List<String> sizesStandard = ['S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', '5XL'];
  static const List<String> sizesNumeric = ['46', '48', '50', '52', '54', '56', '58', '60', '62', '64'];
  static const String sizeRangeHint = 'مثال: 1-60';

  // =========== خيارات الألوان ===========
  static const List<Map<String, dynamic>> colorOptions = [
    {'name': 'أسود', 'hex': '#000000'},
    {'name': 'أبيض', 'hex': '#FFFFFF'},
    {'name': 'كحلي', 'hex': '#0D1B3E'},
    {'name': 'رمادي', 'hex': '#808080'},
    {'name': 'بيج', 'hex': '#F5F5DC'},
    {'name': 'بني', 'hex': '#8B4513'},
    {'name': 'أخضر', 'hex': '#008000'},
    {'name': 'أحمر', 'hex': '#B22222'},
  ];

  // =========== خيارات الفرز ===========
  static const List<Map<String, dynamic>> sortOptions = [
    {'id': 'newest', 'label': 'الأحدث'},
    {'id': 'price_asc', 'label': 'السعر: من الأقل إلى الأعلى'},
    {'id': 'price_desc', 'label': 'السعر: من الأعلى إلى الأقل'},
    {'id': 'popular', 'label': 'الأكثر شهرة'},
    {'id': 'name', 'label': 'الاسم'},
  ];

  // =========== جيب (Jeeb Wallet) ===========
  static const String jeebPosNumber = '573157'; // رقم نقطة البيع لمحفظة جيب
  static const String jeebPackageName = 'com.ahd.jaib'; // حزمة تطبيق جيب على أندرويد
  static const String jeebIconPath = 'assets/images/jeeb_icon.png';

  // =========== كريمي حاسب (Kuraimi Pay) ===========
  static const String kuraimiPosNumber = '1134395'; // رقم نقطة البيع لكريمي حاسب
  static const String kuraimiPackageName = 'com.kuraimi.pay'; // حزمة تطبيق كريمي حاسب (تقديري)
  static const String kuraimiIconPath = 'assets/images/kuraimi_icon.png';

  // =========== طرق الدفع ===========
  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'id': 'kuraimi',
      'name': 'كريمي باي',
      'nameEn': 'Kuraimi Pay',
      'icon': 'kuraimi',
      'iconPath': kuraimiIconPath,
      'description': 'الدفع عبر محفظة كريمي',
    },
    {
      'id': 'jeeb',
      'name': 'جيب',
      'nameEn': 'Jeeb',
      'icon': 'jeeb',
      'iconPath': jeebIconPath,
      'description': 'الدفع عبر محفظة جيب - فتح التطبيق مباشرة',
    },
    {
      'id': 'cod',
      'name': 'الدفع عند الاستلام',
      'nameEn': 'Cash on Delivery',
      'icon': 'cash',
      'description': 'الدفع نقداً عند استلام الطلب',
    },
  ];

  // =========== عملة المتجر ===========
  static const String currency = '﷼';
  static const String currencyCode = 'YER';
  static const double taxRate = 0.05; // 5% ضريبة
  static const double shippingCost = 3000; // 3000 ريال توصيل

  // =========== حدود ===========
  static const int maxCartItems = 50;
  static const int productsPerPage = 20;
  static const int maxAddressesPerUser = 5;

  // =========== Firebase Collections ===========
  static const String firebaseProducts = 'products';
  static const String firebaseUsers = 'users';
  static const String firebaseOrders = 'orders';
  static const String firebaseCategories = 'categories';
  static const String firebaseCarts = 'carts';
  static const String firebaseAddresses = 'addresses';
  static const String firebaseBanners = 'banners';
  static const String firebaseReviews = 'reviews';
  static const String firebaseFlashSales = 'flash_sales';

  // =========== إشعارات FCM ===========
  /// مفتاح خادم FCM (Legacy Server Key) — يُضاف في إعدادات Firebase Console
  /// اتركه فارغاً لتعطيل الإشعارات التلقائية للتخفيضات
  static const String fcmServerKey = '';
}
