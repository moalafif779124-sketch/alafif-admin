import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ----------------------------------------------------------------
// 🎯 أدخل مفتاح Hugging Face API هنا (مجاني)
// سجل واحصل على مفتاح مجاني من https://huggingface.co/settings/tokens
// ----------------------------------------------------------------
String huggingFaceApiKey = '';

/// رابط Space الخاص بـ IDM-VTON العام
String idmVtonSpaceUrl = 'https://yisol-idm-vton.hf.space';

/// حالة طلب الذكاء الاصطناعي
enum PredictionStatus { starting, processing, succeeded, failed }

/// نتيجة طلب الذكاء الاصطناعي
class PredictionResult {
  final String? id;
  final PredictionStatus status;
  final String? outputUrl;
  final String? error;

  PredictionResult({
    this.id,
    required this.status,
    this.outputUrl,
    this.error,
  });

  bool get isDone => status == PredictionStatus.succeeded || status == PredictionStatus.failed;
  bool get isSuccess => status == PredictionStatus.succeeded;
}

/// خدمة التجربة الافتراضية بالذكاء الاصطناعي
/// تستخدم IDM-VTON العام عبر Gradio 4.x SSE API
class AiTryOnService {
  /// إنشاء طلب تجربة افتراضية عبر IDM-VTON Space
  /// [personImagePath] مسار صورة الشخص (محلي)
  /// [garmentImageUrl] رابط صورة المنتج
  /// [category] فئة المنتج (upper_body, lower_body, dresses)
  static Future<PredictionResult> createTryOn({
    required String personImagePath,
    required String garmentImageUrl,
    String category = 'upper_body',
    void Function(String status)? onStatusUpdate,
  }) async {
    if (huggingFaceApiKey.isEmpty) {
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'مفتاح Hugging Face غير مضبط. الرجاء إضافة المفتاح في الإعدادات.',
      );
    }

    try {
      final file = File(personImagePath);
      if (!await file.exists()) {
        return PredictionResult(
          status: PredictionStatus.failed,
          error: 'لم يتم العثور على صورة الشخص',
        );
      }

      debugPrint('🤖 AI Try-On (HF Space): بدء التجربة الافتراضية...');

      // ================================================================
      // تحميل صورة الشخص إلى الـ Space
      // ================================================================
      final personPath = await _uploadImage(file);
      if (personPath == null) {
        return PredictionResult(
          status: PredictionStatus.failed,
          error: 'فشل رفع الصورة. تحقق من الاتصال.',
        );
      }
      debugPrint('📤 تم رفع صورة الشخص: $personPath');

      // ================================================================
      // استدعاء واجهة Gradio 4.x عبر SSE
      // ================================================================
      return await _callGradioSse(
        personPath: personPath,
        garmentImageUrl: garmentImageUrl,
        category: category,
        onStatusUpdate: onStatusUpdate,
      );
    } catch (e) {
      debugPrint('⚠️ AI Try-On (HF Space) خطأ: $e');
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'خطأ في الاتصال: $e',
      );
    }
  }

  /// رفع صورة إلى الـ Space
  static Future<String?> _uploadImage(File file) async {
    try {
      final uploadUri = Uri.parse('$idmVtonSpaceUrl/upload');
      final request = http.MultipartRequest('POST', uploadUri);
      request.files.add(
        await http.MultipartFile.fromPath('files', file.path),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(responseBody);
        if (paths.isNotEmpty) {
          return paths.first.toString();
        }
      }
      debugPrint('⚠️ فشل رفع الصورة: ${streamedResponse.statusCode}');
    } catch (e) {
      debugPrint('⚠️ فشل رفع الصورة: $e');
    }
    return null;
  }

  /// استدعاء Gradio 4.x عبر SSE (queue/join + queue/data)
  static Future<PredictionResult> _callGradioSse({
    required String personPath,
    required String garmentImageUrl,
    required String category,
    void Function(String status)? onStatusUpdate,
  }) async {
    try {
      final sessionHash = _generateSessionHash();
      onStatusUpdate?.call('جارٍ الاتصال بالذكاء الاصطناعي...');
      debugPrint('🔑 Session: $sessionHash');

      // ----------------------------------------
      // الخطوة 1: الانضمام إلى الطابور
      // ----------------------------------------
      final joinPayload = jsonEncode({
        'data': [
          {
            'background': {
              'path': personPath,
              'meta': {'_type': 'gradio.FileData'},
            },
            'layers': <dynamic>[],
            'composite': null,
          },
          garmentImageUrl,
          category,
          true,  // auto-mask
          false, // crop
          30,    // denoising steps
          42,    // seed
        ],
        'fn_index': 2,
        'trigger_id': 25,
        'session_hash': sessionHash,
      });

      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Alafif-Newform/1.0',
      };
      if (huggingFaceApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $huggingFaceApiKey';
      }

      final joinResponse = await http.post(
        Uri.parse('$idmVtonSpaceUrl/queue/join'),
        headers: headers,
        body: joinPayload,
      ).timeout(const Duration(seconds: 30));

      if (joinResponse.statusCode != 200) {
        return PredictionResult(
          status: PredictionStatus.failed,
          error: 'فشل الاتصال بالذكاء الاصطناعي (${joinResponse.statusCode})',
        );
      }

      onStatusUpdate?.call('في طابور الانتظار...');

      final joinData = jsonDecode(joinResponse.body);
      debugPrint('📋 انضم للطابور: ${joinData['event_id']}');

      // ----------------------------------------
      // الخطوة 2: الاستقصاء عبر SSE
      // ----------------------------------------
      final sseUri = Uri.parse('$idmVtonSpaceUrl/queue/data?session_hash=$sessionHash');
      final sseClient = http.Client();
      try {
        final sseRequest = http.Request('GET', sseUri);
        sseRequest.headers.addAll(headers);

        final sseResponse = await sseClient.send(sseRequest);
        final stream = sseResponse.stream.transform(utf8.decoder);
        final completer = Completer<PredictionResult>();
        String buffer = '';

        // استقصاء لمدة أقصاها 10 دقائق
        await Future.any([
          completer.future,
          Future.delayed(const Duration(minutes: 10), () {
            if (!completer.isCompleted) {
              completer.complete(PredictionResult(
                status: PredictionStatus.failed,
                error: 'انتهت مهلة الانتظار (10 دقائق). قد يكون الخادم مشغولاً، حاول مرة أخرى.',
              ));
            }
          }),
        ]);

        // معالجة تدفق SSE
        await for (final chunk in stream) {
          if (completer.isCompleted) break;
          buffer += chunk;

          for (final line in buffer.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                final msg = data['msg'] as String?;

                if (msg == 'process_completed') {
                  final output = data['output'] as Map<String, dynamic>?;
                  final success = data['success'] as bool? ?? false;
                  final error = output?['error'] as String?;

                  if (success && output != null) {
                    final resultData = output['data'] as List<dynamic>?;
                    if (resultData != null && resultData.isNotEmpty) {
                      final outputImage = resultData.first;
                      String? outputUrl = _extractOutputUrl(outputImage);

                      if (outputUrl != null) {
                        completer.complete(PredictionResult(
                          status: PredictionStatus.succeeded,
                          outputUrl: outputUrl,
                        ));
                      } else {
                        completer.complete(PredictionResult(
                          status: PredictionStatus.failed,
                          error: 'لم يتم العثور على رابط الصورة الناتجة',
                        ));
                      }
                    }
                  } else if (error != null && error.isNotEmpty) {
                    completer.complete(PredictionResult(
                      status: PredictionStatus.failed,
                      error: _translateError(error),
                    ));
                  } else {
                    completer.complete(PredictionResult(
                      status: PredictionStatus.failed,
                      error: 'فشلت المعالجة. قد تكون الصور غير مناسبة.',
                    ));
                  }
                  break;
                }

                if (msg == 'process_starts') {
                  onStatusUpdate?.call('يجري المعالجة على GPU...');
                  debugPrint('⏳ بدأت المعالجة...');
                }

                if (msg == 'log') {
                  final logMsg = data['log'] as String? ?? '';
                  if (logMsg.contains('GPU')) {
                    onStatusUpdate?.call(logMsg);
                  }
                  debugPrint('📋 Space: $logMsg');
                }
              } catch (_) {}
            }
          }
          buffer = '';
        }

        if (!completer.isCompleted) {
          completer.complete(PredictionResult(
            status: PredictionStatus.failed,
            error: 'انقطع الاتصال قبل اكتمال المعالجة',
          ));
        }

        return await completer.future;
      } finally {
        sseClient.close();
      }
    } catch (e) {
      debugPrint('⚠️ Gradio SSE فشل: $e');
      return PredictionResult(
        status: PredictionStatus.failed,
        error: 'فشل الاتصال: $e',
      );
    }
  }

  /// استخراج رابط الصورة من استجابة Gradio
  static String? _extractOutputUrl(dynamic output) {
    if (output is String) {
      return output.startsWith('http') ? output : null;
    }
    if (output is Map) {
      if (output['url'] is String) {
        final url = output['url'] as String;
        if (url.startsWith('http')) return url;
      }
      if (output['path'] is String) {
        final path = output['path'] as String;
        return '$idmVtonSpaceUrl/file=$path';
      }
      if (output['name'] is String) {
        final name = output['name'] as String;
        return '$idmVtonSpaceUrl/file=$name';
      }
    }
    return null;
  }

  /// توليد معرف جلسة عشوائي
  static String _generateSessionHash() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// ترجمة رسائل الخطأ
  static String _translateError(String error) {
    if (error.contains('IndexError') || error.contains('out of range')) {
      return 'خطأ في معالجة الصور. تأكد من أن الصورة تحتوي على شخص واضح ومنتج مناسب.';
    }
    if (error.contains('CUDA') || error.contains('GPU') || error.contains('memory')) {
      return 'الذكاء الاصطناعي مشغول حالياً. حاول مرة أخرى بعد دقيقة.';
    }
    if (error.contains('timeout') || error.contains('Timeout')) {
      return 'انتهت مهلة المعالجة. قد تكون الصورة كبيرة جداً.';
    }
    return 'خطأ: $error';
  }

  /// التحقق من حالة الطلب (للتوافق مع الواجهة القديمة)
  static Future<PredictionResult> checkPrediction(String predictionId) async {
    return PredictionResult(
      id: predictionId,
      status: PredictionStatus.failed,
      error: 'لا يدعم الاستقصاء في هذا الإصدار',
    );
  }

  /// تحويل فئة المنتج إلى فئة النموذج
  static String categoryForModel(String categoryId) {
    switch (categoryId) {
      case 'shemagh':
      case 'accessories':
        return 'upper_body';
      case 'thobes':
      case 'bisht':
        return 'dresses';
      default:
        return 'upper_body';
    }
  }
}
