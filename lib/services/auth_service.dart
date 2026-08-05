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

    // 2️⃣ استخدام معرف ثابت يعتمد على رقم الجوال (بدلاً من anonymous auth)
    final cleanPhone = phone.replaceAll('+', '');
    final uid = 'phone_$cleanPhone';
    debugPrint('🔑 Deterministic UID: $uid for phone: $phone');

    // 3️⃣ البحث عن مستخدم موجود بنفس المعرف الثابت
    try {
      final existingUserDoc = await _firebaseService.firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (existingUserDoc.exists) {
        final existingUserData = existingUserDoc.data()!;
        existingUserData['id'] = existingUserDoc.id;
        _pendingPhone = null;
        debugPrint('✅ Existing user found: ${existingUserData['fullName']}');
        return app.AppUser.fromMap(existingUserData);
      }
    } catch (e) {
      debugPrint('⚠️ Firestore search error: $e');
    }

    // 4️⃣ مستخدم جديد - نحتاج اسم
    if (fullName == null || fullName.trim().isEmpty) {
      throw Exception('مطلوب الاسم الكامل للمستخدم الجديد');
    }

    // 5️⃣ إنشاء المستخدم في Firestore
    final user = app.AppUser(
      id: uid,
      fullName: fullName.trim(),
      phone: phone,
      createdAt: DateTime.now(),
    );

    try {
      await _firebaseService.saveUser(user.toMap());
    } catch (e) {
      debugPrint('⚠️ Save user error: $e');
      throw Exception('فشل إنشاء الحساب. حاول مرة أخرى.');
    }

    _pendingPhone = null;
    return user;
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
