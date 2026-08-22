import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'firebase_service.dart';

/// خدمة إرسال إشعارات FCM عبر خادم Vercel الوسيط
///
/// 🔒 الأمان: حساب خدمة Firebase (Service Account) لا يُخزَّن في التطبيق أبداً.
/// التطبيق يرسل إلى Vercel: targetToken + نص الإشعار + بيانات إضافية،
/// ومفتاح API مشترك للمصادقة — والخادم يولّد توكن FCM v1 ويرسل الإشعار.
class NotificationServer {
  final FirebaseService _firebase = FirebaseService();

  /// إرسال إشعار توفر المقاس لمستخدم واحد
  /// - يجلب توكنات FCM للمستخدم من Firestore
  /// - يرسل لكل توكن عبر خادم Vercel
  /// - يرجع عدد الإشعارات التي أُرسلت بنجاح
  Future<int> sendRestockNotification({
    required String userId,
    required String productName,
    required String requestedSize,
    required String productId,
  }) async {
    final tokens = await _firebase.getFcmTokens(userId);
    if (tokens.isEmpty) {
      debugPrint('⚠️ No FCM tokens for user $userId — skipping');
      return 0;
    }

    const title = 'خبر سعيد! مقاسك توفر 🥳';
    final body =
        'مقاس $requestedSize من $productName أصبح متوفراً الآن. سارع بالطلب قبل نفاد الكمية!';

    int sent = 0;
    for (final token in tokens) {
      final ok = await _postToServer(
        targetToken: token,
        title: title,
        body: body,
        data: {
          'type': 'restock',
          'productId': productId,
          'requestedSize': requestedSize,
          'productName': productName,
        },
      );
      if (ok) sent++;
    }
    return sent;
  }

  /// POST إلى خادم Vercel — يرجع true عند نجاح الإرسال
  Future<bool> _postToServer({
    required String targetToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.notificationServerUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': AppConstants.notificationApiKey,
            },
            body: jsonEncode({
              'targetToken': targetToken,
              'title': title,
              'body': body,
              'data': data,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📱 Notification server response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ Notification server error: $e');
      return false;
    }
  }
}
