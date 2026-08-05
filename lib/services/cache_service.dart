import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين المؤقت المحلي — عرض فوري بدون انتظار الشبكة
/// تخزين: البانرات، المنتجات الأولى (15)، إعدادات التنقل
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _keyBanners = 'cache_banners_v1';
  static const _keyProducts = 'cache_products_v1';
  static const _keyNavigation = 'cache_navigation_v1';
  static const _keyBannersTs = 'cache_banners_ts_v1';
  static const _keyProductsTs = 'cache_products_ts_v1';

  SharedPreferences? _prefs;

  /// تهيئة — تُستدعى مرة واحدة من main()
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // =================== الكتابة ===================

  Future<void> saveBanners(List<Map<String, dynamic>> banners) async {
    try {
      final prefs = await _ensure();
      await prefs.setString(_keyBanners, jsonEncode(banners));
      await prefs.setInt(_keyBannersTs, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ Cache save banners failed: $e');
    }
  }

  Future<void> saveProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await _ensure();
      await prefs.setString(_keyProducts, jsonEncode(products));
      await prefs.setInt(_keyProductsTs, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ Cache save products failed: $e');
    }
  }

  Future<void> saveNavigation(Map<String, dynamic> config) async {
    try {
      final prefs = await _ensure();
      await prefs.setString(_keyNavigation, jsonEncode(config));
    } catch (e) {
      debugPrint('⚠️ Cache save navigation failed: $e');
    }
  }

  // =================== القراءة ===================

  Future<List<Map<String, dynamic>>?> getBanners() async {
    try {
      final prefs = await _ensure();
      final raw = prefs.getString(_keyBanners);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('⚠️ Cache read banners failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getProducts() async {
    try {
      final prefs = await _ensure();
      final raw = prefs.getString(_keyProducts);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('⚠️ Cache read products failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getNavigation() async {
    try {
      final prefs = await _ensure();
      final raw = prefs.getString(_keyNavigation);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('⚠️ Cache read navigation failed: $e');
      return null;
    }
  }

  // =================== التواريخ ===================

  Future<int?> get bannersTimestamp async {
    try {
      return (await _ensure()).getInt(_keyBannersTs);
    } catch (_) {
      return null;
    }
  }

  Future<int?> get productsTimestamp async {
    try {
      return (await _ensure()).getInt(_keyProductsTs);
    } catch (_) {
      return null;
    }
  }

  bool isFresh(int? ts, {Duration maxAge = const Duration(hours: 24)}) {
    if (ts == null) return false;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ts),
        ) <
        maxAge;
  }

  // =================== المسح ===================

  Future<void> clearAll() async {
    try {
      final prefs = await _ensure();
      await prefs.remove(_keyBanners);
      await prefs.remove(_keyProducts);
      await prefs.remove(_keyNavigation);
      await prefs.remove(_keyBannersTs);
      await prefs.remove(_keyProductsTs);
    } catch (e) {
      debugPrint('⚠️ Cache clear failed: $e');
    }
  }

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}
