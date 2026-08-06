import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app;
import 'firebase_service.dart';

/// خدمة المصادقة - OTP عبر واتساب + البريد الإلكتروني
class AuthService {
  final FirebaseService _firebaseService = FirebaseService();

  String? _pendingPhone;
  String? get pendingPhone => _pendingPhone;

  // =================== OTP عبر واتساب ===================

  String _generateOtpCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _buildWhatsAppUrl(String phone, String otpCode) {
    final cleanPhone = phone.replaceAll('+', '');
    final message = Uri.encodeComponent(
      'رمز التحقق الخاص بك في العفيف نيوفورم هو: $otpCode\n'
      'يرجى عدم مشاركة هذا الرمز مع أي شخص.'
    );
    return 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$message';
  }

  /// إنشاء OTP وتحضير رابط واتساب
  Future<Map<String, String>> sendOtp(String phone) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    final otpCode = _generateOtpCode();
    _pendingPhone = phone;

    debugPrint('🔐 OTP generated for $phone: $otpCode');

    final whatsappUrl = _buildWhatsAppUrl(phone, otpCode);

    return {
      'otp': otpCode,
      'phone': phone,
      'whatsappUrl': whatsappUrl,
    };
  }

  /// إعادة إرسال OTP (يولّد رمز جديد) — يُستخدم مع AuthProvider.resendOtp()
  Future<Map<String, String>> resendOtp() async {
    if (_pendingPhone == null) {
      throw Exception('الرجاء إدخال رقم الجوال أولاً');
    }
    return sendOtp(_pendingPhone!);
  }

  /// التحقق من OTP + إنشاء/تسجيل دخول - خطوة واحدة
  /// [otp] رمز التحقق الذي أدخله المستخدم
  /// [expectedOtp] رمز التحقق المتوقع (من AuthProvider)
  /// [phone] رقم الجوال
  /// [fullName] الاسم الكامل (مطلوب للمستخدم الجديد)
  Future<app.AppUser> createOrLoginUser({
    required String otp,
    required String expectedOtp,
    required String phone,
    String? fullName,
  }) async {
    // 1️⃣ التحقق من صلاحية OTP
    if (expectedOtp.isEmpty) {
      throw Exception('الرجاء إرسال رمز التحقق أولاً');
    }
    if (otp != expectedOtp) {
      throw Exception('رمز التحقق غير صحيح');
    }
    // OTP صحيح — نكمل

    // 2️⃣ إنشاء جلسة Firebase Auth (مجهولة الهوية)
    // — شرط أساسي لقواعد Firestore الأمنية (request.auth != null)
    UserCredential credential;
    try {
      credential = await _firebaseService.auth.signInAnonymously();
    } catch (e) {
      debugPrint('⚠️ Anonymous sign-in error: $e');
      throw Exception('فشل الاتصال بخدمة التحقق. حاول مرة أخرى.');
    }
    final authUid = credential.user!.uid;
    debugPrint('🔑 Firebase Auth UID: $authUid for phone: $phone');

    // 3️⃣ البحث عن مستخدم مسجل على هذا الجهاز (نفس جلسة Firebase)
    try {
      final existingUserDoc = await _firebaseService.firestore
          .collection('users')
          .doc(authUid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (existingUserDoc.exists) {
        final existingUserData = existingUserDoc.data()!;

        // 🔧 إصلاح ذاتي: إذا فشل الترحيل أول مرة (شبكة ضعيفة) وفقد isAdmin
        // بينما الحساب القديم (phone_<رقم>) مدير — نستعيد الصلاحية فوراً
        if (existingUserData['isAdmin'] != true) {
          final healed = await healAdminFromLegacy(uid: authUid, phone: phone);
          if (healed) {
            final refreshed = await _firebaseService.firestore
                .collection('users')
                .doc(authUid)
                .get()
                .timeout(const Duration(seconds: 10));
            if (refreshed.exists) {
              existingUserData.addAll(refreshed.data()!);
            }
          }
        }

        existingUserData['id'] = existingUserDoc.id;
        _pendingPhone = null;
        debugPrint('✅ User session found: ${existingUserData['fullName']}');
        return app.AppUser.fromMap(existingUserData);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore search error: $e');
    }

    // 4️⃣ ترحيل الحساب القديم (phone_<number>) إلى معرف Firebase الجديد
    // — يحافظ على النقاط والعناوين والطلبات والمفضلة المسجلة سابقاً
    final legacyId = 'phone_${phone.replaceAll('+', '')}';
    if (legacyId != authUid) {
      final migrated =
          await _migrateLegacyUser(legacyId: legacyId, newUid: authUid, phone: phone);
      if (migrated != null) {
        _pendingPhone = null;
        return migrated;
      }
    }

    // 5️⃣ مستخدم جديد - نحتاج اسم
    if (fullName == null || fullName.trim().isEmpty) {
      throw Exception('مطلوب الاسم الكامل للمستخدم الجديد');
    }

    // 6️⃣ إنشاء المستخدم في Firestore بمعرف Firebase الرسمي
    final user = app.AppUser(
      id: authUid,
      fullName: fullName.trim(),
      phone: phone,
      createdAt: DateTime.now(),
    );

    final userMap = user.toMap();
    // رقم الجوال كحقل مستقل (متوافق مع قواعد Firestore الجديدة)
    userMap['phoneNumber'] = phone;

    try {
      await _firebaseService.saveUser(userMap);
    } catch (e) {
      debugPrint('⚠️ Save user error: $e');
      throw Exception('فشل إنشاء الحساب. حاول مرة أخرى.');
    }

    _pendingPhone = null;
    return user;
  }

  /// 🔧 إصلاح ذاتي: استرجاع صلاحية المدير من الحساب القديم (phone_<رقم>)
  /// إذا فشل الترحيل أثناء أول تسجيل دخول (شبكة ضعيفة) — يعيد true عند النجاح
  Future<bool> healAdminFromLegacy({
    required String uid,
    required String phone,
  }) async {
    if (uid.isEmpty || phone.isEmpty) return false;
    final legacyId = 'phone_${phone.replaceAll('+', '')}';
    if (legacyId == uid) return false;
    try {
      final current = await _firebaseService.firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!current.exists) return false;
      if (current.data()?['isAdmin'] == true) return false; // مدير بالفعل

      final legacy = await _firebaseService.firestore
          .collection('users')
          .doc(legacyId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!legacy.exists) return false;
      final legacyData = legacy.data()!;
      if (legacyData['isAdmin'] != true) return false;

      // دمج صلاحية المدير + رقم الجوال في الوثيقة الجديدة
      await _firebaseService.firestore.collection('users').doc(uid).update({
        'isAdmin': true,
        'phone': phone,
        'phoneNumber': phone,
      });
      // ترحيل البيانات المرتبطة (طلبات/عناوين/مفضلة/نقاط)
      await _migrateUserData(legacyId: legacyId, newUid: uid);
      debugPrint('🔧 Admin healed from legacy: $legacyId → $uid');
      return true;
    } catch (e) {
      debugPrint('⚠️ Admin heal error: $e');
      return false;
    }
  }

  /// ترحيل حساب المستخدم القديم (phone_<number>) إلى معرف Firebase Auth الجديد
  Future<app.AppUser?> _migrateLegacyUser({
    required String legacyId,
    required String newUid,
    required String phone,
  }) async {
    try {
      final legacyDoc = await _firebaseService.firestore
          .collection('users')
          .doc(legacyId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!legacyDoc.exists) return null;

      final data = Map<String, dynamic>.from(legacyDoc.data()!);
      data['id'] = newUid;
      data['phone'] = phone;
      data['phoneNumber'] = phone;
      data['migratedAt'] = DateTime.now().millisecondsSinceEpoch;

      // نسخ وثيقة المستخدم إلى المعرف الجديد ثم حذف القديمة
      await _firebaseService.firestore
          .collection('users')
          .doc(newUid)
          .set(data, SetOptions(merge: true));
      // الحذف بجهدٍ ممكن — قد تمنعه قواعد Firestore (حساب قديم بدون مالك)
      try {
        await _firebaseService.firestore
            .collection('users')
            .doc(legacyId)
            .delete();
      } catch (e) {
        debugPrint('⚠️ Legacy doc delete skipped (rules): $e');
      }

      // ترحيل البيانات المرتبطة (طلبات/عناوين/مفضلة/نقاط)
      await _migrateUserData(legacyId: legacyId, newUid: newUid);

      debugPrint('♻️ Legacy user migrated: $legacyId → $newUid');
      return app.AppUser.fromMap(data);
    } catch (e) {
      debugPrint('⚠️ Legacy migration error: $e');
      return null;
    }
  }

  /// نقل وثائق المستخدم المرتبطة من المعرف القديم إلى الجديد
  Future<void> _migrateUserData({
    required String legacyId,
    required String newUid,
  }) async {
    const collections = [
      'orders',
      'addresses',
      'wishlists',
      'points_history',
      'carts',
    ];
    for (final collection in collections) {
      try {
        final snap = await _firebaseService.firestore
            .collection(collection)
            .where('userId', isEqualTo: legacyId)
            .limit(400)
            .get()
            .timeout(const Duration(seconds: 15));
        final batch = _firebaseService.firestore.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'userId': newUid});
        }
        await batch.commit().timeout(const Duration(seconds: 15));
        debugPrint('♻️ Migrated ${snap.docs.length} docs in $collection');
      } catch (e) {
        debugPrint('⚠️ Migration skip $collection: $e');
      }
    }
  }

  void cancelOtp() {
    _pendingPhone = null;
  }

  // =================== التسجيل بالبريد الإلكتروني ===================

  Future<app.AppUser> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    UserCredential userCredential;
    try {
      userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception('فشل إنشاء الحساب: $e');
    }

    final user = app.AppUser(
      id: userCredential.user!.uid,
      fullName: fullName,
      phone: phone ?? '',
      email: email,
      createdAt: DateTime.now(),
    );

    await _firebaseService.saveUser(user.toMap());
    return user;
  }

  // =================== تسجيل الدخول بالبريد الإلكتروني ===================

  Future<app.AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    try {
      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(email: email, password: password);

      final userData = await _firebaseService.getUser(userCredential.user!.uid);
      if (userData != null) {
        return app.AppUser.fromMap(userData);
      }

      return app.AppUser(
        id: userCredential.user!.uid,
        fullName: 'مستخدم',
        email: email,
        phone: '',
      );
    } catch (e) {
      throw Exception('فشل تسجيل الدخول: $e');
    }
  }

  // =================== تسجيل الخروج ===================

  Future<void> logout() async {
    cancelOtp();
    await _firebaseService.auth.signOut();
  }

  // =================== الحالة ===================

  Stream<User?> get authStateChanges =>
      _firebaseService.auth.authStateChanges();

  User? get currentUser => _firebaseService.auth.currentUser;
  bool get isLoggedIn => _firebaseService.auth.currentUser != null;

  // =================== إعادة تعيين كلمة المرور ===================

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseService.auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('فشل إرسال رابط إعادة التعيين: $e');
    }
  }

  // =================== تحديث الملف الشخصي ===================

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? profileImage,
    String? phone,
  }) async {
    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['fullName'] = fullName;
    if (profileImage != null) updates['profileImage'] = profileImage;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .update(updates);
    }
  }
}
