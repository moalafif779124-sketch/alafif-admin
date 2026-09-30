import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// نغمة التنبيه الحرجة للموظفين (إلغاء العميل لطلب غرفة القياس).
///
/// - النغمة مسجّلة كملف محلي في `assets/sounds/cancellation_alert.wav`
///   (لا شبكة، لا تأخير تحميل — الصوت لازم يطلع فوراً في الفرع).
/// - تُشغَّل مرة واحدة فقط لكل طلب خلال نافذة زمنية قصيرة، حتى لو فتح
///   الموظف الشاشة أكثر من مرة أو بقيت شاشة سابقة في الحزمة، فلا تتكرر
///   النغمة على نفس الإلغاء.
/// - أي فشل في الصوت لا يُسقط الواجهة (التنبيه البصري يكفي).
class AlertSound {
  AlertSound._();

  static final AlertSound instance = AlertSound._();

  /// المسار نسبةً إلى مجلد `assets/` (audioplayers يضيف البادئة تلقائياً)
  static const String cancellationChime = 'sounds/cancellation_alert.wav';

  /// نافذة كبت التكرار لنفس الطلب
  static const Duration _dedupeWindow = Duration(seconds: 20);

  final AudioPlayer _player = AudioPlayer(playerId: 'alafif_staff_alerts');

  /// آخر تشغيل لكل طلب — لكبت التكرار
  final Map<String, DateTime> _playedAt = {};

  bool _ready = false;

  /// تهيئة مبكرة (تُستدعى في initState) لتقليل زمن الاستجابة للنغمة.
  Future<void> warmUp() async {
    if (_ready) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource(cancellationChime));
      _ready = true;
    } catch (e) {
      debugPrint('⚠️ Alert sound warm-up failed: $e');
    }
  }

  /// تشغيل نغمة الإلغاء. [requestId] لمفتاح كبت التكرار.
  Future<void> playCancellationChime({String requestId = ''}) async {
    if (_isDuplicate(requestId)) return;

    try {
      if (!_ready) {
        await warmUp();
      }
      // stop + play من البداية: النغمة قد تكون لا تزال تُعزف من إلغاء سابق
      await _player.stop();
      await _player.play(AssetSource(cancellationChime), volume: 1.0);
      _ready = true;
    } catch (e) {
      debugPrint('⚠️ Cancellation chime failed: $e');
      _ready = false;
    }
  }

  bool _isDuplicate(String requestId) {
    if (requestId.isEmpty) return false;
    final now = DateTime.now();
    final last = _playedAt[requestId];
    if (last != null && now.difference(last) < _dedupeWindow) return true;

    _playedAt[requestId] = now;
    if (_playedAt.length > 50) {
      _playedAt.removeWhere(
        (_, t) => now.difference(t) > const Duration(minutes: 5),
      );
    }
    return false;
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // لا شيء — الإغلاق لا يجب أن يفشل
    }
  }
}
