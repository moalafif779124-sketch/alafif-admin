import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// عنصر من كتالوج الأصناف المضمّن في التطبيق (كشف الأصناف).
///
/// يُحمَّل من الأصل المحلي `assets/data/product_catalog.json` — يعمل بلا
/// إنترنت وبسرعة فائقة داخل الفرع، ويغطي كل أصناف المتجر (23 ألف صنف).
class CatalogEntry {
  /// الرمز (باركود/كود الصنف) كما يُطبع على بطاقة المنتج.
  final String code;

  /// اسم الصنف.
  final String name;

  /// سعر البيع.
  final double salePrice;

  /// سعر التخفيضات (0 إن لم يوجد).
  final double discountPrice;

  /// المجموعة/الفئة.
  final String category;

  const CatalogEntry({
    required this.code,
    required this.name,
    required this.salePrice,
    required this.discountPrice,
    required this.category,
  });

  /// هل يوجد تخفيض فعلي (سعر تخفيضات أقل من سعر البيع)؟
  bool get hasDiscount =>
      discountPrice > 0 && salePrice > 0 && discountPrice < salePrice;

  /// السعر المعروض للعميل: التخفيض إن وُجد وإلا سعر البيع.
  double get currentPrice => hasDiscount ? discountPrice : salePrice;

  /// السعر الأصلي المشطوب (فقط عند وجود تخفيض).
  double? get originalPrice => hasDiscount ? salePrice : null;
}

/// خدمة البحث في كتالوج الأصناف المضمّن.
///
/// - تُحمّل الخريطة مرة واحدة فقط (lazy) في isolate منفصل كي لا تُجمّد الواجهة.
/// - البحث لحظي بمفتاح الرمز بعد التطبيع.
class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  static const String _assetPath = 'assets/data/product_catalog.json';

  Map<String, CatalogEntry>? _index;
  Future<Map<String, CatalogEntry>>? _loading;

  /// حجم الكتالوج بعد التحميل (للتشخيص).
  int get size => _index?.length ?? 0;

  /// تطبيع الرمز: حذف المسافات والأصفار الكسرية (100001.0 → 100001).
  static String normalizeCode(String raw) {
    var code = raw.trim();
    if (code.contains('product/')) code = code.split('product/').last;
    code = code.replaceAll('"', '').replaceAll("'", '').trim();
    if (code.contains('?')) code = code.split('?').first;
    // أزل الأصفار الكسرية الناتجة عن قراءة أرقام من Excel (100001.0 → 100001)
    if (code.endsWith('.0')) code = code.substring(0, code.length - 2);
    return code.trim();
  }

  /// يضمن تحميل الفهرس (آمن للاستدعاء المتكرر والمتوازي).
  Future<Map<String, CatalogEntry>> ensureLoaded() {
    final loaded = _index;
    if (loaded != null) return Future.value(loaded);
    return _loading ??= _load();
  }

  Future<Map<String, CatalogEntry>> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    // فكّ الترميز في isolate منفصل (٢٫٢MB) — لا يعطّل الـ UI.
    final index = await compute(_parseCatalog, raw);
    _index = index;
    return index;
  }

  /// يبحث عن صنف بالرمز. يعيد null إن لم يوجد.
  Future<CatalogEntry?> lookup(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) return null;
    final index = await ensureLoaded();
    // مطابقة مباشرة
    final direct = index[code];
    if (direct != null) return direct;
    // مطابقة حسّاسة-لحالة الأحرف (الرموز التي تحوي حروفاً مثل 180075B)
    final upper = code.toUpperCase();
    for (final key in index.keys) {
      if (key.toUpperCase() == upper) return index[key];
    }
    return null;
  }

  /// بحث فوري بدون انتظار (إن كان الفهرس محمّلاً)، للتحقق السريع.
  CatalogEntry? lookupSync(String rawCode) {
    final index = _index;
    if (index == null) return null;
    final code = normalizeCode(rawCode);
    if (code.isEmpty) return null;
    final direct = index[code];
    if (direct != null) return direct;
    final upper = code.toUpperCase();
    for (final key in index.keys) {
      if (key.toUpperCase() == upper) return index[key];
    }
    return null;
  }
}

/// يُشغَّل في isolate: يحوّل نص JSON إلى خريطة عناصر جاهزة.
Map<String, CatalogEntry> _parseCatalog(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final result = <String, CatalogEntry>{};
  decoded.forEach((code, value) {
    // value = [name, salePrice, discountPrice, category]
    if (value is! List || value.isEmpty) return;
    final name = (value[0] ?? '').toString();
    final sale = value.length > 1 ? _toDouble(value[1]) : 0.0;
    final disc = value.length > 2 ? _toDouble(value[2]) : 0.0;
    final cat = value.length > 3 ? (value[3] ?? '').toString() : '';
    result[code] = CatalogEntry(
      code: code,
      name: name,
      salePrice: sale,
      discountPrice: disc,
      category: cat,
    );
  });
  return result;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}
