import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

/// مزود النقاط والتحقق اليومي — Gamification Engine
class PointsProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  int _points = 0;
  int _lifetimePoints = 0;
  int _streakDays = 0;
  bool _checkedInToday = false;
  bool _isLoading = false;
  String? _userId;

  // =================== Getters ===================

  int get points => _points;
  int get lifetimePoints => _lifetimePoints;
  int get streakDays => _streakDays;
  bool get checkedInToday => _checkedInToday;
  bool get isLoading => _isLoading;

  /// سعر التحويل: 100 نقطة = 375 ريال
  static const int pointsToYerRate = 375;
  static const int pointsPerUnit = 100;

  double get discountValue => ((_points ~/ pointsPerUnit) * pointsToYerRate).toDouble();

  // =================== أيام الأسبوع للتسلسل ===================
  List<bool> get weekCheckins {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon .. 7=Sun
    return List.generate(7, (i) {
      if (_streakDays == 0) return false;
      // آخر streakDays يوم كانت متصلة
      return i < _streakDays;
    });
  }

  // =================== التهيئة ===================

  Future<void> initialize(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _firebaseService.getUserPoints(userId);
      if (data != null) {
        _points = data['points'] ?? 0;
        _lifetimePoints = data['lifetimePoints'] ?? 0;
        _streakDays = data['streakDays'] ?? 0;
        final lastCheckin = data['lastCheckin'] as int?;
        if (lastCheckin != null) {
          final lastDate =
              DateTime.fromMillisecondsSinceEpoch(lastCheckin);
          _checkedInToday = _isSameDay(lastDate, DateTime.now());
        }
      } else {
        await _createUserPoints(userId);
      }
    } catch (e) {
      debugPrint('Error loading points: $e');
      // حاول من SharedPreferences
      await _restoreFromPrefs();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _createUserPoints(String userId) async {
    await _firebaseService.saveUserPoints(userId, {
      'points': 0,
      'lifetimePoints': 0,
      'streakDays': 0,
      'lastCheckin': 0,
    });
  }

  // =================== التحقق اليومي (Check-in) ===================

  Future<bool> checkIn() async {
    if (_checkedInToday || _userId == null) return false;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastCheckinStr = prefs.getString('last_checkin_${_userId}');

    int newStreak = 1;
    if (lastCheckinStr != null) {
      final lastDate = DateTime.tryParse(lastCheckinStr);
      if (lastDate != null) {
        final diff = now.difference(lastDate).inDays;
        if (diff == 1) {
          newStreak = _streakDays + 1;
        } else if (diff == 0) {
          return false; // already checked in
        }
        // diff > 1 = streak broken, reset to 1
      }
    }

    // مكافآت التتالي (Streak Bonuses)
    int bonus = 10; // أساسي
    if (newStreak >= 30) {
      bonus = 200;
    } else if (newStreak >= 14) {
      bonus = 100;
    } else if (newStreak >= 7) {
      bonus = 50;
    } else if (newStreak >= 3) {
      bonus = 25;
    }

    _points += bonus;
    _lifetimePoints += bonus;
    _streakDays = newStreak;
    _checkedInToday = true;

    // حفظ في SharedPreferences
    await prefs.setString(
        'last_checkin_${_userId}', now.toIso8601String());
    await prefs.setInt('points_${_userId}', _points);
    await prefs.setInt('streak_${_userId}', _streakDays);

    // مزامنة مع Firestore (fire-and-forget)
    _syncToFirestore();

    notifyListeners();
    return true;
  }

  // =================== إدارة النقاط ===================

  Future<void> addPoints(int amount, {String? reason}) async {
    _points += amount;
    _lifetimePoints += amount;
    notifyListeners();
    await _syncToFirestore();
  }

  Future<bool> spendPoints(int amount) async {
    if (_points < amount) return false;
    _points -= amount;
    notifyListeners();
    await _syncToFirestore();
    return true;
  }

  /// خصم النقاط عند الاسترداد في السلة — مع تسجيل سجل معاملة
  Future<bool> deductPoints(int amount, {String? orderId, String? note}) async {
    if (_points < amount) return false;
    _points -= amount;
    notifyListeners();
    await _syncToFirestore();
    // تسجيل المعاملة في سجل النقاط
    await _recordHistory(-amount, orderId: orderId, note: note ?? 'استرداد نقاط في الطلب');
    return true;
  }

  /// إضافة نقاط مع تسجيل سجل معاملة
  Future<void> addPointsWithHistory(int amount, {String? note}) async {
    _points += amount;
    _lifetimePoints += amount;
    notifyListeners();
    await _syncToFirestore();
    await _recordHistory(amount, note: note ?? 'مكافأة');
  }

  /// تسجيل معاملة في سجل النقاط (users/{userId}/points_history)
  Future<void> _recordHistory(int delta, {String? orderId, String? note}) async {
    if (_userId == null) return;
    try {
      await _firebaseService.addPointsHistory(_userId!, {
        'delta': delta,
        'balance': _points,
        'orderId': orderId,
        'note': note ?? '',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to record points history: $e');
    }
  }

  // =================== المزامنة ===================

  Future<void> _syncToFirestore() async {
    if (_userId == null) return;
    try {
      await _firebaseService.updateUserPoints(_userId!, {
        'points': _points,
        'lifetimePoints': _lifetimePoints,
        'streakDays': _streakDays,
        'lastCheckin': _checkedInToday
            ? DateTime.now().millisecondsSinceEpoch
            : 0,
      });
    } catch (e) {
      debugPrint('Error syncing points: $e');
    }
  }

  Future<void> _restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _points = prefs.getInt('points_${_userId}') ?? 0;
    _streakDays = prefs.getInt('streak_${_userId}') ?? 0;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void setUserId(String uid) {
    _userId = uid;
  }
}
