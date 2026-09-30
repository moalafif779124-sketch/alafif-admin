/// مراقب إلغاء العميل لطلبات غرفة القياس.
///
/// السبب: الموظف قد يكون في منتصف إحضار القطعة من المخزن، فيلغي العميل
/// الطلب من تطبيقه — يجب أن يتوقف فوراً. لذلك نراقب تدفّق Firestore
/// ونكتشف *الانتقال* إلى حالة `cancelled` التي مصدرها العميل.
///
/// كيف نفرّق؟ تطبيق العميل يكتب `cancelledBy: 'customer'`، وتطبيق الموظف
/// يكتب `cancelledBy: 'staff'` — فلا ننبّه الموظف على إلغائه هو.
///
/// لا يُنبّه على الإلغاءات القديمة: أول دفعة تُسجَّل فقط بلا تنبيه
/// (_primed)، ففتح الشاشة لا يُشعل تنبيهات تاريخية.
class FittingRoomCancellationWatcher {
  /// آخر حالة معروفة لكل طلب — لاكتشاف الانتقال
  final Map<String, String> _lastStatus = {};

  /// أول دفعة = تسجيل بلا تنبيه
  bool _primed = false;

  /// هل تم تسجيل الدفعة الأولى؟ (مفيد في الاختبارات)
  bool get primed => _primed;

  /// حالات «نشطة» — الإلغاء منها يستحق تنبيهاً
  static const Set<String> _activeStatuses = {'pending', 'accepted', 'ready'};

  /// يفحص دفعة الطلبات ويعيد ما ألغاه العميل الآن (قد تكون قائمة فارغة).
  List<Map<String, dynamic>> scan(List<Map<String, dynamic>> requests) {
    final hits = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final r in requests) {
      final id = (r['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      seen.add(id);

      final status = (r['status'] as String?) ?? 'pending';
      final previous = _lastStatus[id];
      _lastStatus[id] = status;

      if (!_primed) continue;
      if (status != 'cancelled') continue;
      // كان ملغى في الدفعة السابقة (أو أُبلغ عنه سابقاً) — لا تكرار
      if (previous == 'cancelled') continue;
      // إلغاء الموظف نفسه أو مصدر غير معروف — لا تنبيه
      if (!isCustomerCancellation(r)) continue;
      // انتقال غير متوقع من حالة غير نشطة — لا تنبيه
      if (previous != null && !_activeStatuses.contains(previous)) continue;

      hits.add(r);
    }

    // تنظيف الطلبات التي خرجت من البث (نطاق محدود — لا نمو غير محدود)
    _lastStatus.removeWhere((id, _) => !seen.contains(id));
    _primed = true;

    return hits;
  }

  /// هل الإلغاء مصدره العميل؟ (الحقل يكتبه تطبيق العميل)
  static bool isCustomerCancellation(Map<String, dynamic> request) =>
      ((request['cancelledBy'] as String?) ?? '').trim().toLowerCase() ==
      'customer';

  /// نص التنبيه: «تم إلغاء الطلب من قبل العميل: المنتج - مقاس المقاس»
  static String cancellationMessage(Map<String, dynamic> request) {
    final name = ((request['productName'] as String?) ?? '').trim();
    final size = ((request['size'] as String?) ?? '').trim();
    final product = name.isEmpty ? 'منتج' : name;
    return 'تم إلغاء الطلب من قبل العميل: $product - مقاس ${size.isEmpty ? 'موحّد' : size}';
  }
}
