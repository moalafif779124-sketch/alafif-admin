import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import '../config/constants.dart';

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

  // =================== رفع الصور ===================

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
        
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
      }
    } catch (e) {
      debugPrint('⚠️ uploadImage error: $e');
      rethrow;
    }
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

  /// تحديث حالة الطلب
  Future<void> updateOrderStatus(String orderId, String status) async {
    final update = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (status == 'delivered') {
      update['deliveredAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    await firestore.collection('orders').doc(orderId).update(update);
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

  /// إنشاء تخفيض خاطف جديد — مع إرسال إشعار FCM للموضوع
  Future<String> createFlashSale(Map<String, dynamic> data) async {
    final docRef = await firestore.collection('flash_sales').add(data);

    // إرسال إشعار FCM تلقائي (fire-and-forget — لا يحجب الحفظ)
    try {
      final productName = data['productName'] as String? ?? 'منتجنا';
      final discount = data['discountPercentage'] ?? 0;
      final productId = data['productId'] as String? ?? '';
      unawaited(_sendFlashSaleNotification(
        discount.toString(),
        productName,
        productId: productId,
      ));
    } catch (e) {
      debugPrint('⚠️ Flash sale notification dispatch failed: $e');
    }

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

  /// إرسال إشعار FCM لموضوع /topics/flash_sales عبر HTTP v1
  Future<void> _sendFlashSaleNotification(
      String discount, String productName,
      {String productId = ''}) async {
    try {
      final http = await _sendFcmHttpNotification(
        title: '⚡ تخفيض خاطف جديد!',
        body: 'خصم $discount% على $productName لمدة محدودة! تسوق الآن.',
        topic: 'flash_sales',
        data: {
          'type': 'flash_sale',
          'productId': productId,
          'title': '⚡ تخفيض خاطف جديد!',
          'body': 'خصم $discount% على $productName لمدة محدودة! تسوق الآن.',
        },
      );
      if (!http) {
        debugPrint('⚠️ FCM topic send returned false');
      }
    } catch (e) {
      debugPrint('⚠️ FCM send error: $e');
    }
  }

  /// إرسال إشعار FCM عبر HTTP API (topic أو token)
  Future<bool> _sendFcmHttpNotification({
    required String title,
    required String body,
    String? topic,
    String? token,
    Map<String, String>? data,
  }) async {
    try {
      final serverKey = AppConstants.fcmServerKey;
      if (serverKey.isEmpty) return false;
      final uri = Uri.parse('https://fcm.googleapis.com/fcm/send');
      final message = <String, dynamic>{
        if (topic != null) 'to': '/topics/$topic',
        if (token != null) 'to': token,
        'notification': {'title': title, 'body': body},
        'data': data ?? {
          'type': 'flash_sale',
          'title': title,
          'body': body,
        },
      };
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(message),
      );
      if (response.statusCode != 200) {
        debugPrint('⚠️ FCM HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ FCM send exception: $e');
      return false;
    }
  }
}
