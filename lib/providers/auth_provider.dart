import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// مزود حالة المصادقة - يدعم OTP عبر واتساب والبريد الإلكتروني
/// يحفظ جلسة OTP في SharedPreferences ويقرأها منها مباشرة عند التحقق
/// (لا يعتمد على الذاكرة المؤقتة لأن Android قد يقتل العملية)
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  
  // حالة OTP — ملء احتياطي، المصدر الأساسي هو SharedPreferences
  bool _otpSent = false;
  String? _otpCode;
  String? _whatsappUrl;
  String? _pendingPhone;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;
  bool get otpSent => _otpSent;
  String? get otpCode => _otpCode;
  String? get whatsappUrl => _whatsappUrl;
  String? get pendingPhone => _pendingPhone;

  // =================== حفظ/استرجاع OTP من SharedPreferences ===================

  Future<void> _saveOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_otpCode != null) await prefs.setString('otp_code', _otpCode!);
      if (_pendingPhone != null) await prefs.setString('pending_phone', _pendingPhone!);
      await prefs.setBool('otp_sent', _otpSent);
      debugPrint('💾 OTP session saved to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to save OTP session: $e');
    }
  }

  Future<void> _clearOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('otp_code');
      await prefs.remove('pending_phone');
      await prefs.remove('otp_sent');
      debugPrint('🗑️ OTP session cleared from SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to clear OTP session: $e');
    }
  }

  /// حفظ بيانات المستخدم في SharedPreferences للحفاظ على الجلسة
  Future<void> _saveUserSession() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user_id', _user!.id);
      await prefs.setString('saved_user_name', _user!.fullName);
      await prefs.setString('saved_user_phone', _user!.phone);
      await prefs.setBool('saved_user_admin', _user!.isAdmin);
      debugPrint('💾 User session saved to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to save user session: $e');
    }
  }

  /// مسح جلسة المستخدم المحفوظة
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_user_id');
      await prefs.remove('saved_user_name');
      await prefs.remove('saved_user_phone');
      await prefs.remove('saved_user_admin');
      debugPrint('🗑️ User session cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear user session: $e');
    }
  }

  /// استرجاع جلسة OTP من SharedPreferences — يُستدعى عند فتح شاشة OTP
  Future<void> restoreOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final otpCode = prefs.getString('otp_code');
      final pendingPhone = prefs.getString('pending_phone');
      final otpSent = prefs.getBool('otp_sent');

      if (otpCode != null && pendingPhone != null) {
        _otpCode = otpCode;
        _pendingPhone = pendingPhone;
        _otpSent = otpSent ?? true;
        notifyListeners();
        debugPrint('♻️ OTP session restored: phone=$pendingPhone, code=$otpCode');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore OTP session: $e');
    }
  }

  /// قراءة OTP من SharedPreferences مباشرة — المصدر الأساسي الموثوق
  Future<Map<String, String>?> _readOtpFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('otp_code');
      final phone = prefs.getString('pending_phone');
      if (code != null && phone != null) {
        return {'otpCode': code, 'phone': phone};
      }
    } catch (e) {
      debugPrint('⚠️ Failed to read OTP from Prefs: $e');
    }
    return null;
  }

  // =================== التهيئة ===================

  Future<void> initialize() async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    // 1️⃣ محاولة استرجاع الجلسة المحفوظة من SharedPreferences
    final restored = await _restoreSavedSession();
    if (restored) {
      debugPrint('♻️ User session restored from SharedPreferences');
      // 🐛 FIX: Re-fetch from Firestore to get latest admin status
      // OTP users have no Firebase Auth session, so authStateChanges
      // never fires for them — this ensures admin role is current on app start
      await refreshUser();
    }

    // 2️⃣ استرجاع جلسة OTP عند بدء التطبيق (إذا كان في منتصف عملية تحقق)
    await restoreOtpSession();

    // 3️⃣ الاستماع لتغييرات حالة Firebase Auth (تحديث البيانات في الخلفية)
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUser(firebaseUser.uid);
      }
      // لا نمسح الجلسة عند غياب Firebase Auth (لأننا نستخدم SP)
    });
  }

  /// استرجاع الجلسة المحفوظة من SharedPreferences
  Future<bool> _restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('saved_user_id');
      if (savedId == null || savedId.isEmpty) return false;

      final savedName = prefs.getString('saved_user_name') ?? '';
      final savedPhone = prefs.getString('saved_user_phone') ?? '';
      final savedAdmin = prefs.getBool('saved_user_admin') ?? false;

      if (savedId.isNotEmpty) {
        _user = AppUser(
          id: savedId,
          fullName: savedName,
          phone: savedPhone,
          isAdmin: savedAdmin,
        );
        notifyListeners();
        debugPrint('♻️ Session restored: $savedName (admin: $savedAdmin)');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore session: $e');
    }
    return false;
  }

  Future<void> _loadUser(String uid) async {
    try {
      final userData = await _firebaseService.getUser(uid);
      if (userData != null) {
        _user = AppUser.fromMap(userData);
        await _saveUserSession();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  // =================== الدخول بالجوال (OTP عبر واتساب) ===================

  /// توليد OTP وتحضير رابط واتساب (لا يرسل شيء، يفتح واتساب فقط)
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = phone;
    notifyListeners();

    try {
      final result = await _authService.sendOtp(phone);
      
      _otpCode = result['otp'];
      _whatsappUrl = result['whatsappUrl'];
      _pendingPhone = result['phone'];
      _otpSent = true;
      _isLoading = false;
      
      // 💾 حفظ جلسة OTP في SharedPreferences قبل العودة
      await _saveOtpSession();
      
      // ✅ تحقق إضافي: نقرأ من SharedPreferences ونتأكد أن البيانات محفوظة
      final saved = await _readOtpFromPrefs();
      if (saved == null) {
        debugPrint('⚠️ WARNING: OTP not persisted to SharedPreferences!');
      } else {
        debugPrint('✅ OTP confirmed in SharedPreferences: ${saved['otpCode']}');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إعادة إرسال OTP
  Future<bool> resendOtp() async {
    if (_pendingPhone == null) {
      _error = 'الرجاء إدخال رقم الجوال أولاً';
      notifyListeners();
      return false;
    }
    return sendOtp(_pendingPhone!);
  }

  /// تأكيد رمز OTP وإتمام تسجيل الدخول
  /// يقرأ رمز OTP من SharedPreferences مباشرة (المصدر الأساسي)
  Future<bool> confirmOtp({
    required String otp,
    String? fullName,
  }) async {
    // ♻️ قراءة OTP من SharedPreferences مباشرة — المصدر الأساسي
    final savedOtp = await _readOtpFromPrefs();
    
    String expectedCode;
    String pendingPhoneNumber;
    
    if (savedOtp != null) {
      // ✅ وجدنا OTP في SharedPreferences — نستخدمه
      expectedCode = savedOtp['otpCode']!;
      pendingPhoneNumber = savedOtp['phone']!;
      // نحدّث الذاكرة احتياطياً
      _otpCode = expectedCode;
      _pendingPhone = pendingPhoneNumber;
      debugPrint('📖 Read OTP from SharedPreferences: $expectedCode');
    } else {
      // ❌ لا يوجد OTP في SharedPreferences — نستخدم الذاكرة كاحتياط أخير
      expectedCode = _otpCode ?? '';
      pendingPhoneNumber = _pendingPhone ?? '';
      debugPrint('⚠️ OTP not in SharedPreferences, using memory: $expectedCode');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.createOrLoginUser(
        otp: otp,
        expectedOtp: expectedCode,
        phone: pendingPhoneNumber,
        fullName: fullName,
      );
      
      // 💾 حفظ الجلسة بعد تسجيل الدخول
      await _saveUserSession();
      
      // 🗑️ مسح جلسة OTP بعد نجاح تسجيل الدخول
      await _clearOtpSession();
      
      _otpSent = false;
      _otpCode = null;
      _whatsappUrl = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إلغاء عملية OTP
  void cancelOtp() {
    _clearOtpSession();
    _authService.cancelOtp();
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = null;
    _error = null;
    notifyListeners();
  }

  // =================== التسجيل بالبريد الإلكتروني ===================

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      await _saveUserSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =================== تسجيل الدخول بالبريد الإلكتروني ===================

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      await _saveUserSession();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =================== تسجيل الخروج ===================

  Future<void> logout() async {
    await _clearUserSession();
    await _clearOtpSession();
    await _authService.logout();
    _user = null;
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = null;
    notifyListeners();
  }

  // =================== تحديث الملف الشخصي ===================

  Future<void> updateProfile({
    String? fullName,
    String? profileImage,
  }) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateProfile(
        userId: _user!.id,
        fullName: fullName,
        profileImage: profileImage,
      );

      if (fullName != null) {
        _user = AppUser(
          id: _user!.id,
          fullName: fullName,
          phone: _user!.phone,
          email: _user!.email,
          profileImage: profileImage ?? _user!.profileImage,
          address: _user!.address,
          createdAt: _user!.createdAt,
          isAdmin: _user!.isAdmin,  // 🐛 FIX: preserve admin role
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // =================== تحديث بيانات المستخدم من Firestore ===================

  /// إعادة جلب بيانات المستخدم من Firestore وتحديث الجلسة
  /// يُستدعى عندما يريد المستخدم التحقق من صلاحياته المحدثة
  Future<bool> refreshUser() async {
    if (_user == null) return false;
    try {
      final userData = await _firebaseService.getUser(_user!.id);
      if (userData != null) {
        _user = AppUser.fromMap(userData);
        await _saveUserSession();
        notifyListeners();
        debugPrint('♻️ User refreshed from Firestore: admin=${_user!.isAdmin}');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to refresh user: $e');
    }
    return false;
  }

  // =================== مسح الأخطاء ===================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
