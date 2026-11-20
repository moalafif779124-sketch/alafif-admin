import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img_pkg;
import '../config/constants.dart';
import 'stock_restock.dart';

/// نتيجة عملية إرجاع المخزون (تظهر في رسالة للمسؤول).
class RestockReport {
  /// سبق إرجاع مخزون هذا الطلب — لم يُلمس أي منتج الآن.
  final bool alreadyDone;

  /// عدد مستندات المنتجات التي تغيّر مخزونها.
  final int products;

  /// عدد القطع التي أُرجعت فعلاً.
  final int pieces;

  /// أسطر لم تُرجَع (منتج محذوف / مقاس غير معروف).
  final List<String> warnings;

  const RestockReport({
    required this.alreadyDone,
    this.products = 0,
    this.pieces = 0,
    this.warnings = const [],
  });

  String get summary {
    if (alreadyDone) return 'مخزون هذا الطلب أُرجِع سابقاً ✓';
    if (pieces == 0) return 'لا مخزون مُتتبَّع لهذا الطلب — لم يُرجَع شيء';
    return 'أُرجعت $pieces قطعة إلى $products منتج';
  }
}

/// خدمة Firebase المركزية
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAuth? _auth;
  bool _initialized = false;

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _storage!;
  }

  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _auth!;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _storage = FirebaseStorage.instance;
    _auth = FirebaseAuth.instance;
    _initialized = true;

    // إعدادات Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  bool get isInitialized => _initialized;

  // =================== المنتجات ===================

  Stream<List<Map<String, dynamic>>> getProductsStream({
    String? categoryId,
    bool? isFeatured,
    bool? isNewArrival,
    String? searchQuery,
    String? sortBy,
    bool ascending = false,
  }) {
    Query query = firestore.collection('products').where('isActive', isEqualTo: true);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (isFeatured != null) {
      query = query.where('isFeatured', isEqualTo: isFeatured);
    }
    if (isNewArrival != null) {
      query = query.where('isNewArrival', isEqualTo: isNewArrival);
    }

    // ترتيب
    String sortField = 'createdAt';
    if (sortBy == 'price_asc' || sortBy == 'price_desc') {
      sortField = 'price';
    } else if (sortBy == 'name') {
      sortField = 'name';
    } else if (sortBy == 'popular') {
      sortField = 'reviewCount';
    }
    query = query.orderBy(sortField, descending: sortBy == 'price_desc' || sortBy == 'popular' || sortBy == 'newest');

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data()! as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// جلب المنتجات مع دعم التحميل المُقسّم (pagination) وحقول البطاقة فقط
  /// [limit] — عدد المنتجات المطلوبة (null = الكل)
  /// [lastDocument] — آخر مستند للتحميل التصفحي (cursor pagination)
  /// [cardOnly] — true = جلب حقول البطاقة فقط للعرض السريع
  Future<Map<String, dynamic>> getProducts({
    String? categoryId,
    bool? isFeatured,
    bool? isNewArrival,
    String? searchQuery,
    String? sortBy,
    int? limit,
    DocumentSnapshot? lastDocument,
    bool cardOnly = false,
  }) async {
    Query query = firestore.collection('products').where('isActive', isEqualTo: true);

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (isFeatured != null) {
      query = query.where('isFeatured', isEqualTo: isFeatured);
    }
    if (isNewArrival != null) {
      query = query.where('isNewArrival', isEqualTo: isNewArrival);
    }

    if (sortBy != null) {
      String sortField = 'createdAt';
      if (sortBy == 'price_asc' || sortBy == 'price_desc') sortField = 'price';
      else if (sortBy == 'name') sortField = 'name';
      else if (sortBy == 'popular') sortField = 'reviewCount';
      query = query.orderBy(sortField, descending: sortBy == 'price_desc' || sortBy == 'popular' || sortBy == 'newest');
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    final products = snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    return {
      'products': products,
      'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      'hasMore': snapshot.docs.length >= (limit ?? snapshot.docs.length),
    };
  }

  /// جلب منتج كامل (جميع الحقول) — يُستدعى عند فتح شاشة التفاصيل فقط
  Future<Map<String, dynamic>?> getProduct(String productId) async {
    final doc = await firestore.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  // =================== الفئات ===================

  Stream<List<Map<String, dynamic>>> getCategoriesStream() {
    return firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final snapshot = await firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== البانرات ===================

  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final snapshot = await firestore
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order', descending: false)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== إدارة البانرات (لوحة المدير) ===================

  Future<List<Map<String, dynamic>>> getAllBanners() async {
    final snapshot = await firestore
        .collection('banners')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<String> addBanner(Map<String, dynamic> data) async {
    final docRef = await firestore.collection('banners').add(data);
    return docRef.id;
  }

  Future<void> updateBanner(String bannerId, Map<String, dynamic> data) async {
    await firestore.collection('banners').doc(bannerId).update(data);
  }

  Future<void> deleteBanner(String bannerId) async {
    await firestore.collection('banners').doc(bannerId).delete();
  }

  /// جلب البانرات مرتبة حسب حقل order
  Future<List<Map<String, dynamic>>> getBannersByOrder() async {
    final snapshot = await firestore
        .collection('banners')
        .orderBy('order', descending: false)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== إعدادات التنقل (Tab Management) ===================

  Future<Map<String, dynamic>?> getNavigationConfig() async {
    try {
      final doc = await firestore.collection('app_config').doc('navigation').get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get navigation config: $e');
    }
    return null;
  }

  Future<void> saveNavigationConfig(Map<String, dynamic> data) async {
    try {
      await firestore.collection('app_config').doc('navigation').set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Failed to save navigation config: $e');
    }
  }

  /// تحديث تبويب معين في إعدادات التنقل
  Future<void> updateTabConfig(String tabId, Map<String, dynamic> data) async {
    try {
      await firestore.collection('app_config').doc('navigation').update({
        'tabs.$tabId': data,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update tab config: $e');
    }
  }

  // =================== السلة ===================

  Future<void> saveCart(String userId, List<Map<String, dynamic>> items) async {
    await firestore.collection('carts').doc(userId).set({
      'userId': userId,
      'items': items,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>?> getCart(String userId) async {
    final doc = await firestore.collection('carts').doc(userId).get();
    if (!doc.exists) return null;
    return List<Map<String, dynamic>>.from(doc.data()!['items'] ?? []);
  }

  Future<void> clearCart(String userId) async {
    await firestore.collection('carts').doc(userId).delete();
  }

  // =================== المفضلة (قائمة الرغبات) ===================

  Future<void> saveWishlist(String userId, List<String> productIds) async {
    await firestore.collection('wishlists').doc(userId).set({
      'userId': userId,
      'productIds': productIds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<String>?> getWishlist(String userId) async {
    final doc = await firestore.collection('wishlists').doc(userId).get();
    if (!doc.exists) return null;
    return List<String>.from(doc.data()!['productIds'] ?? []);
  }

  Future<void> clearWishlist(String userId) async {
    await firestore.collection('wishlists').doc(userId).delete();
  }

  // =================== الطلبات ===================

  /// جلب طلب معين بواسطة ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final doc = await firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      debugPrint('⚠️ Failed to get order: $e');
      return null;
    }
  }

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final docRef = await firestore.collection('orders').add(orderData);
    return docRef.id;
  }

  Stream<List<Map<String, dynamic>>> getUserOrdersStream(String userId) {
    return firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    final snapshot = await firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== العناوين ===================

  Future<void> saveAddress(Map<String, dynamic> addressData) async {
    if (addressData['id'] != null && addressData['id'].isNotEmpty) {
      await firestore.collection('addresses').doc(addressData['id']).set(addressData);
    } else {
      await firestore.collection('addresses').add(addressData);
    }
  }

  Future<List<Map<String, dynamic>>> getUserAddresses(String userId) async {
    final snapshot = await firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> deleteAddress(String addressId) async {
    await firestore.collection('addresses').doc(addressId).delete();
  }

  Future<void> setDefaultAddress(String userId, String addressId) async {
    final batch = firestore.batch();
    final addresses = await firestore
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in addresses.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == addressId});
    }
    await batch.commit();
  }

  // =================== أكواد الخصم ===================

  /// كل الأكواد — المفتاح في Firestore هو الكود نفسه (أحرف كبيرة).
  Future<List<Map<String, dynamic>>> getCoupons() async {
    try {
      final snap = await firestore.collection('coupons').get();
      final list = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['code'] = d.id;
        return m;
      }).toList();
      list.sort((a, b) =>
          (a['code'] as String).toLowerCase().compareTo((b['code'] as String).toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('⚠️ getCoupons: $e');
      return [];
    }
  }

  Future<void> saveCoupon(String code, Map<String, dynamic> data) async {
    await firestore
        .collection('coupons')
        .doc(code.trim().toUpperCase())
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteCoupon(String code) async {
    await firestore.collection('coupons').doc(code).delete();
  }

  Future<void> setCouponActive(String code, bool active) async {
    await firestore.collection('coupons').doc(code).update({'active': active});
  }

  // =================== رفع الصور ===================

  /// ضغط صورة محلية وإرجاعها base64 (بلا Storage):
  /// 900px عرضاً أقصى، JPEG q60 → ~40-80KB بدل 300-500KB.
  static Future<String> compressToBase64(
    String localPath, {
    int maxPx = 900,
    int quality = 60,
  }) async {
    final bytes = await io.File(localPath).readAsBytes();
    var img = img_pkg.decodeImage(bytes);
    if (img == null) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
    final w = img.width, h = img.height;
    if (w > maxPx || h > maxPx) {
      final scale = maxPx / (w > h ? w : h);
      img = img_pkg.copyResize(
        img,
        width: (w * scale).round(),
        height: (h * scale).round(),
        interpolation: img_pkg.Interpolation.average,
      );
    }
    final out = img_pkg.encodeJpg(img, quality: quality);
    return 'data:image/jpeg;base64,${base64Encode(out)}';
  }

  /// إعادة ترميز صورة base64 موجودة إلى صورة مصغّرة (thumb).
  static Future<String> base64ToThumb(String dataUri,
      {int maxPx = 240, int quality = 70}) async {
    try {
      if (!dataUri.startsWith('data:image')) return dataUri;
      final bytes = base64Decode(dataUri.split(',').last);
      var img = img_pkg.decodeImage(bytes);
      if (img == null) return '';
      final w = img.width, h = img.height;
      if (w > maxPx || h > maxPx) {
        final scale = maxPx / (w > h ? w : h);
        img = img_pkg.copyResize(img,
            width: (w * scale).round(), height: (h * scale).round());
      }
      return 'data:image/jpeg;base64,${base64Encode(img_pkg.encodeJpg(img, quality: quality))}';
    } catch (e) {
      debugPrint('⚠️ base64ToThumb: $e');
      return '';
    }
  }

  /// معرض الصور الكامل — خارج مستند المنتج (كي لا يتضخّم الكتالوج).
  Future<void> saveProductGallery(
      String productId, List<String> images) async {
    await firestore.collection('product_images').doc(productId).set({
      'images': images,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<List<String>> getProductGallery(String productId) async {
    try {
      final doc =
          await firestore.collection('product_images').doc(productId).get();
      final imgs = doc.data()?['images'];
      if (imgs is List) return imgs.whereType<String>().toList();
    } catch (e) {
      debugPrint('⚠️ getProductGallery: $e');
    }
    return const <String>[];
  }

  /// رفع صورة إلى Firebase Storage (أو تخزينها كـ base64 إذا كان التخزين غير مفعل)
  Future<String> uploadImage(String localPath, String fileName) async {
    try {
      final file = io.File(localPath);
      if (!await file.exists()) {
        throw Exception('الملف غير موجود: $localPath');
      }
      
      // محاولة رفع الصورة إلى Firebase Storage أولاً
      try {
        final ref = storage.ref().child('products/$fileName');
        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      } catch (storageError) {
        // إذا فشل التخزين السحابي (غير مفعل أو بدون billing)،
        // نخزن الصورة كـ base64 داخل Firestore مباشرة
        debugPrint('⚠️ Firebase Storage failed, using base64 fallback: $storageError');
        
        // ضغط إلزامي: بلا Storage تكون الصورة داخل مستند Firestore
        // (سقف 1MB) — الصورة الخام 300-500KB تخنق الكتالوج.
        return await compressToBase64(localPath, maxPx: 900, quality: 60);
      }
    } catch (e) {
      debugPrint('⚠️ uploadImage error: $e');
      rethrow;
    }
  }

  /// رفع فيديو المنتج إلى Firebase Storage
  /// لا يوجد بديل base64 للفيديو — عند الفشل يُطلب رابط مباشر بدلاً من ذلك
  Future<String> uploadVideo(String localPath, String fileName) async {
    final file = io.File(localPath);
    if (!await file.exists()) {
      throw Exception('الملف غير موجود: $localPath');
    }
    final ref = storage.ref().child('products/videos/$fileName');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  // =================== إدارة المنتجات (Admin) ===================

  /// إضافة منتج جديد
  Future<String> addProduct(Map<String, dynamic> data) async {
    data.remove('id'); // لا نريد id مكرر
    data['isActive'] = true;
    data['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    final docRef = await firestore.collection('products').add(data);
    return docRef.id;
  }

  /// تحديث منتج موجود
  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    data.remove('id');
    await firestore.collection('products').doc(productId).update(data);
  }

  /// حذف منتج (إخفاء فقط للحفاظ على البيانات)
  Future<void> deleteProduct(String productId) async {
    await firestore.collection('products').doc(productId).update({
      'isActive': false,
    });
  }

  /// جلب كل المنتجات (بما فيها غير النشطة)
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final snapshot = await firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== إدارة الفئات (Admin) ===================

  /// إضافة فئة جديدة
  Future<String> addCategory(Map<String, dynamic> data) async {
    data.remove('id');
    data['isActive'] = true;
    final docRef = await firestore.collection('categories').add(data);
    return docRef.id;
  }

  /// تحديث فئة موجودة
  Future<void> updateCategory(String categoryId, Map<String, dynamic> data) async {
    data.remove('id');
    await firestore.collection('categories').doc(categoryId).update(data);
  }

  /// حذف فئة
  Future<void> deleteCategory(String categoryId) async {
    await firestore.collection('categories').doc(categoryId).update({
      'isActive': false,
    });
  }

  /// جلب كل الفئات
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final snapshot = await firestore
        .collection('categories')
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // =================== إدارة الطلبات (Admin) ===================

  /// جلب كل الطلبات
  Stream<List<Map<String, dynamic>>> getAllOrdersStream() {
    return firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final snapshot = await firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// تحديث حالة الدفع — تستخدمه شاشة الطلبات بعد مراجعة إثبات التحويل
  /// (كريمي/جيب): تحوّل الطلب إلى «تم الدفع» وتختم من تحقق ومتى.
  /// [confirmOrder] يجعل الطلب «مؤكداً» إن كان ما زال قيد المراجعة.
  Future<void> updatePaymentStatus(
    String orderId,
    String status, {
    bool confirmOrder = false,
  }) async {
    final update = <String, dynamic>{
      'paymentStatus': status,
      'paymentVerifiedAt': DateTime.now().millisecondsSinceEpoch,
      'paymentVerifiedBy': auth.currentUser?.uid,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (confirmOrder) {
      update['status'] = 'confirmed';
    }
    await firestore.collection('orders').doc(orderId).update(update);
  }

  /// إرجاع المخزون عند إلغاء الطلب — عملية معاملاتية واحدة.
  ///
  /// [cancelOrder] = true يعني أيضاً تحويل الحالة إلى `cancelled` (رفض/إلغاء
  /// من لوحة الإدارة). إن كان الطلب ملغياً مسبقاً (ألغاه العميل) فاستدعها
  /// بالـ false كي تُرجع المخزون فقط.
  ///
  /// الحماية من الإرجاع المزدوج: مستند الطلب يأخذ `stockRestored = true`
  /// مرة واحدة داخل نفس المعاملة، فأي استدعاء لاحق يخرج فوراً بلا لمس المنتجات.
  Future<RestockReport> restoreOrderStock(
    String orderId, {
    bool cancelOrder = false,
  }) async {
    final orderRef = firestore.collection('orders').doc(orderId);

    return firestore.runTransaction<RestockReport>((tx) async {
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('الطلب غير موجود');
      }
      final data = orderSnap.data()!;
      final alreadyCancelled = data['status'] == 'cancelled';

      if (data['stockRestored'] == true) {
        if (cancelOrder && !alreadyCancelled) {
          tx.update(orderRef, {
            'status': 'cancelled',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
        return const RestockReport(alreadyDone: true);
      }

      // اجمع الكميات المطلوبة لكل منتج (مقاس → كمية، وإجمالي)
      final byProduct = <String, Map<String, int>>{};
      final totalByProduct = <String, int>{};
      final items = (data['items'] as List?) ?? const [];
      for (final raw in items) {
        final item = (raw as Map).cast<String, dynamic>();
        final productId = (item['productId'] ?? '').toString();
        if (productId.isEmpty) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final size = (item['size'] ?? '').toString().trim();
        totalByProduct[productId] = (totalByProduct[productId] ?? 0) + qty;
        final bySize = byProduct.putIfAbsent(productId, () => <String, int>{});
        if (size.isNotEmpty) {
          bySize[size] = (bySize[size] ?? 0) + qty;
        }
      }

      if (byProduct.isEmpty) {
        if (cancelOrder) {
          tx.update(orderRef, {
            'status': 'cancelled',
            'stockRestored': true,
            'stockRestoredAt': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
        return const RestockReport(alreadyDone: false, products: 0, pieces: 0);
      }

      // اقرأ كل المنتجات أولاً (شرط Firestore: كل القراءات قبل الكتابات)
      final productRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final productId in byProduct.keys) {
        final ref = firestore.collection('products').doc(productId);
        productRefs[productId] = ref;
        productSnaps[productId] = await tx.get(ref);
      }

      var productsTouched = 0;
      var piecesRestored = 0;
      final warnings = <String>[];

      for (final entry in byProduct.entries) {
        final productId = entry.key;
        final snap = productSnaps[productId]!;
        if (!snap.exists) {
          warnings.add('منتج محذوف ($productId) — لم يُرجَع مخزونه');
          continue;
        }
        final p = snap.data()!;
        final variants = <String, int>{};
        (p['stockVariants'] as Map?)?.forEach((k, v) {
          variants[k.toString()] = (v as num).toInt();
        });
        final plan = computeRestock(
          productName: (p['name'] ?? productId).toString(),
          stockVariants: variants,
          stockQuantity: (p['stockQuantity'] as num?)?.toInt() ?? 0,
          restoreBySize: entry.value,
          restoreTotal: totalByProduct[productId] ?? 0,
        );
        warnings.addAll(plan.warnings);

        if (!plan.tracked || plan.restoredPieces == 0) continue;

        final update = <String, dynamic>{
          'stockUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        if (plan.stockVariants.isNotEmpty) {
          update['stockVariants'] = plan.stockVariants;
        }
        if (plan.stockQuantity != null) {
          update['stockQuantity'] = plan.stockQuantity;
        }
        tx.update(productRefs[productId]!, update);
        productsTouched++;
        piecesRestored += plan.restoredPieces;
      }

      tx.update(orderRef, {
        if (cancelOrder) 'status': 'cancelled',
        'stockRestored': true,
        'stockRestoredAt': DateTime.now().millisecondsSinceEpoch,
        'stockRestoredPieces': piecesRestored,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return RestockReport(
        alreadyDone: false,
        products: productsTouched,
        pieces: piecesRestored,
        warnings: warnings,
      );
    });
  }

  /// تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String status) async {
    // الإلغاء يمر عبر معاملة الإرجاع: المخزون خُصم وقت الإنشاء، فإلغاء بلا
    // إرجاع يعني «ضياع» قطع من المخزون إلى الأبد (كان هذا هو السلوك سابقاً).
    if (status == 'cancelled') {
      await restoreOrderStock(orderId, cancelOrder: true);
      return;
    }
    final update = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (status == 'delivered') {
      update['deliveredAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    await firestore.collection('orders').doc(orderId).update(update);
  }

  // =================== طلبات توفر المخزن (Admin) ===================

  /// بث مباشر لطلبات توفر المخزن — الأحدث أولاً
  Stream<List<Map<String, dynamic>>> getRestockRequestsStream() {
    return firestore
        .collection('restock_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// تحديث حالة طلب توفر إلى "تم توفره" (resolved)
  Future<void> markRestockResolved(String requestId) async {
    await firestore.collection('restock_requests').doc(requestId).update({
      'status': 'resolved',
      'resolvedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // =================== طلبات غرفة القياس (Admin) ===================

  /// بث مباشر لطلبات غرفة القياس — الأحدث أولاً.
  ///
  /// استعلام بحقل واحد فقط (createdAt) — لا يحتاج فهرساً مركّباً،
  /// والتصفية حسب الفرع/الحالة تحدث في الواجهة.
  Stream<List<Map<String, dynamic>>> getFittingRoomRequestsStream() {
    return firestore
        .collection('fitting_room_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// تحديث حالة طلب غرفة القياس:
  /// pending → accepted (جاري الإحضار) → ready (في الغرفة) → done (تم التسليم)
  /// ويمكن الإلغاء من أي حالة نشطة (cancelled).
  ///
  /// `cancelledBy` يوضّح مصدر الإلغاء: تطبيق الموظف يكتب `staff`، وتطبيق
  /// العميل يكتب `customer` — وعلى هذا الحقل يعتمد تنبيه الإلغاء عند الموظف.
  Future<void> updateFittingRoomRequestStatus(
    String requestId,
    String status, {
    String handledBy = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final update = <String, dynamic>{
      'status': status,
      'updatedAt': now,
    };

    switch (status) {
      case 'accepted':
        update['acceptedAt'] = now;
        break;
      case 'ready':
        update['readyAt'] = now;
        break;
      case 'done':
        update['doneAt'] = now;
        break;
      case 'cancelled':
        update['cancelledAt'] = now;
        update['cancelledBy'] = 'staff';
        break;
    }

    if (handledBy.isNotEmpty) update['handledBy'] = handledBy;

    await firestore
        .collection('fitting_room_requests')
        .doc(requestId)
        .update(update);
  }

  // =================== المستخدم (Admin) ===================

  Future<void> saveUser(Map<String, dynamic> userData) async {
    await firestore.collection('users').doc(userData['id']).set(userData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  /// جلب جميع المستخدمين (للمدير)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// تبديل صلاحية المدير لمستخدم
  Future<void> toggleAdmin(String userId, bool isAdmin) async {
    await firestore.collection('users').doc(userId).update({
      'isAdmin': isAdmin,
    });
  }

  /// تحديث أي حقل لمستخدم (للمدير)
  Future<void> updateUserField(String userId, Map<String, dynamic> updates) async {
    updates.remove('id');
    await firestore.collection('users').doc(userId).update(updates);
  }

  /// الحصول على عدد المستخدمين
  Future<int> getUserCount() async {
    final snapshot = await firestore.collection('users').count().get();
    return snapshot.count ?? 0;
  }

  // =================== التقييمات والمراجعات ===================

  /// جلب مراجعات منتج معين
  Future<List<Map<String, dynamic>>> getProductReviews(String productId) async {
    final snapshot = await firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data()! as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Stream لمراجعات منتج معين
  Stream<List<Map<String, dynamic>>> getProductReviewsStream(String productId) {
    return firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// إضافة مراجعة جديدة
  Future<String> addReview(Map<String, dynamic> data) async {
    data['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    final docRef = await firestore.collection('reviews').add(data);

    // تحديث متوسط التقييم للمنتج
    await _updateProductRating(data['productId']);
    return docRef.id;
  }

  /// تحديث متوسط التقييم للمنتج بناءً على المراجعات
  Future<void> _updateProductRating(String productId) async {
    try {
      final reviews = await firestore
          .collection('reviews')
          .where('productId', isEqualTo: productId)
          .get();

      if (reviews.docs.isEmpty) return;

      double totalRating = 0;
      for (var doc in reviews.docs) {
        final data = doc.data()! as Map<String, dynamic>;
        totalRating += (data['rating'] ?? 5).toDouble();
      }
      final averageRating = (totalRating / reviews.docs.length);
      final reviewCount = reviews.docs.length;

      await firestore.collection('products').doc(productId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'reviewCount': reviewCount,
      });
    } catch (e) {
      debugPrint('Error updating product rating: $e');
    }
  }

  /// التحقق مما إذا كان المستخدم قد قيّم المنتج بالفعل
  Future<bool> hasUserReviewed(String productId, String userId) async {
    final snapshot = await firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // =================== FCM Tokens (الإشعارات) ===================

  /// حفظ FCM token للمستخدم
  Future<void> saveFcmToken(String userId, String token) async {
    try {
      final userDoc = firestore.collection('users').doc(userId);
      final existing = await userDoc.get();
      if (existing.exists) {
        // إضافة token إلى مصفوفة fcmTokens (لنفقد لا شيء)
        final currentTokens = List<String>.from(existing.data()?['fcmTokens'] ?? []);
        if (!currentTokens.contains(token)) {
          currentTokens.add(token);
          // الحفاظ على آخر 5 tokens فقط
          while (currentTokens.length > 5) {
            currentTokens.removeAt(0);
          }
          await userDoc.update({'fcmTokens': currentTokens});
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to save FCM token: $e');
    }
  }

  /// جلب FCM tokens لمستخدم
  Future<List<String>> getFcmTokens(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['fcmTokens'] ?? []);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get FCM tokens: $e');
    }
    return [];
  }

  /// حذف FCM token (عند تسجيل الخروج)
  Future<void> removeFcmToken(String userId, String token) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final currentTokens = List<String>.from(doc.data()?['fcmTokens'] ?? []);
        currentTokens.remove(token);
        await firestore.collection('users').doc(userId).update({
          'fcmTokens': currentTokens,
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to remove FCM token: $e');
    }
  }

  // =================== نقاط المستخدمين (Gamification) ===================

  /// جلب بيانات نقاط المستخدم
  Future<Map<String, dynamic>?> getUserPoints(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data()!.containsKey('points')) {
        return {
          'points': doc.data()!['points'] ?? 0,
          'lifetimePoints': doc.data()!['lifetimePoints'] ?? 0,
          'streakDays': doc.data()!['streakDays'] ?? 0,
          'lastCheckin': doc.data()!['lastCheckin'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get user points: $e');
    }
    return null;
  }

  /// حفظ بيانات النقاط الأولية
  Future<void> saveUserPoints(String userId, Map<String, dynamic> data) async {
    try {
      await firestore.collection('users').doc(userId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Failed to save user points: $e');
    }
  }

  /// تحديث نقاط المستخدم
  Future<void> updateUserPoints(String userId, Map<String, dynamic> data) async {
    try {
      await firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      debugPrint('⚠️ Failed to update user points: $e');
    }
  }

  /// تسجيل معاملة في سجل نقاط المستخدم (users/{userId}/points_history)
  Future<void> addPointsHistory(String userId, Map<String, dynamic> data) async {
    try {
      await firestore.collection('users').doc(userId).collection('points_history').add(data);
    } catch (e) {
      debugPrint('⚠️ Failed to add points history: $e');
    }
  }

  // =================== إشعارات المواضيع (Topic Subscriptions) ===================

  /// تسجيل اشتراك في موضوع إشعارات
  Future<void> subscribeToTopic(String userId, String topic) async {
    try {
      final doc = firestore.collection('users').doc(userId);
      final existing = await doc.get();
      final topics = List<String>.from(existing.data()?['notificationTopics'] ?? []);
      if (!topics.contains(topic)) {
        topics.add(topic);
        await doc.update({'notificationTopics': topics});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to subscribe to topic: $e');
    }
  }

  /// إلغاء الاشتراك من موضوع إشعارات
  Future<void> unsubscribeFromTopic(String userId, String topic) async {
    try {
      final doc = firestore.collection('users').doc(userId);
      final existing = await doc.get();
      final topics = List<String>.from(existing.data()?['notificationTopics'] ?? []);
      topics.remove(topic);
      await doc.update({'notificationTopics': topics});
    } catch (e) {
      debugPrint('⚠️ Failed to unsubscribe from topic: $e');
    }
  }

  /// جلب مواضيع الإشعارات المشترك بها
  Future<List<String>> getNotificationTopics(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['notificationTopics'] ?? []);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get notification topics: $e');
    }
    return [];
  }

  // =================== التخفيضات الخاطفة (Flash Sales) ===================

  /// إنشاء تخفيض خاطف جديد
  /// (الإشعار يُرسل تلقائياً من خادم Firebase عبر Cloud Function
  /// عند إنشاء الوثيقة — بدون مفتاح خادم داخل التطبيق)
  Future<String> createFlashSale(Map<String, dynamic> data) async {
    final docRef = await firestore.collection('flash_sales').add(data);
    return docRef.id;
  }

  /// جلب التخفيضات الخاطفة النشطة
  Future<List<Map<String, dynamic>>> getActiveFlashSales() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final snapshot = await firestore
          .collection('flash_sales')
          .where('endTime', isGreaterThan: now)
          .orderBy('startTime', descending: true)
          .limit(20)
          .get();
      return snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        d['id'] = doc.id;
        return d;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Failed to get active flash sales: $e');
      return [];
    }
  }

  /// جلب كل التخفيضات الخاطفة (للوحة التحكم)
  Future<List<Map<String, dynamic>>> getAllFlashSales() async {
    try {
      final snapshot = await firestore
          .collection('flash_sales')
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        d['id'] = doc.id;
        return d;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Failed to get all flash sales: $e');
      return [];
    }
  }

  /// حذف تخفيض خاطف
  Future<void> deleteFlashSale(String id) async {
    try {
      await firestore.collection('flash_sales').doc(id).delete();
    } catch (e) {
      debugPrint('⚠️ Failed to delete flash sale: $e');
    }
  }
}
