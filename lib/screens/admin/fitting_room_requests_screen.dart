import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/alert_sound.dart';
import '../../services/firebase_service.dart';
import '../../services/fitting_room_cancellation_watcher.dart';
import '../../services/notification_server.dart';
import '../../widgets/app_image.dart';

/// مظهر حالة طلب غرفة القياس — التسمية واللون والأيقونة
class _StatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusStyle(this.label, this.color, this.icon);
}

/// خرائط الحالات — تُستخدم في الشرائح والبطاقات ولوحة الملخص
const Map<String, _StatusStyle> _statusStyles = {
  'pending': _StatusStyle('جديد', AppColors.warning, Icons.fiber_new),
  'accepted': _StatusStyle('جاري الإحضار', AppColors.info, Icons.directions_run),
  'ready': _StatusStyle('في غرفة القياس', AppColors.success, Icons.checkroom),
  'done': _StatusStyle('تم التسليم', AppColors.textSecondary, Icons.verified),
  'cancelled': _StatusStyle('ملغي', AppColors.error, Icons.cancel_outlined),
};

_StatusStyle _styleOf(String? status) =>
    _statusStyles[status ?? 'pending'] ?? _statusStyles['pending']!;

/// الشاشة إدارة طلبات غرفة القياس — تصل من تطبيق العميل عبر
/// «الوضع الذكي داخل الفرع» → «إحضار لغرفة القياس».
///
/// الموظف يرى الطلبات مباشرة (بث حي)، مرتبة الأحدث أولاً، مجمّعة حسب الفرع،
/// ويتحرك بها عبر: جديد → جاري الإحضار → في غرفة القياس → تم التسليم.
class FittingRoomRequestsScreen extends StatefulWidget {
  const FittingRoomRequestsScreen({super.key});

  @override
  State<FittingRoomRequestsScreen> createState() =>
      _FittingRoomRequestsScreenState();
}

class _FittingRoomRequestsScreenState extends State<FittingRoomRequestsScreen> {
  final FirebaseService _firebase = FirebaseService();

  /// مراقب إلغاء العميل — يشتغل على نفس البث
  final FittingRoomCancellationWatcher _cancelWatcher =
      FittingRoomCancellationWatcher();

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  /// أحدث دفعة من البث (بلا سحب للتحديث — Firestore يدفع التغيير)
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  Object? _error;

  /// إلغاءات العميل المكتشفة في هذه الجلسة (الأحدث أولاً) — لافتة حمراء ثابتة
  final List<Map<String, dynamic>> _customerCancellations = [];

  /// معرّفات الطلبات التي ألغاها العميل — لتمييز البطاقة باللون الأحمر
  final Set<String> _customerCancelledIds = {};

  /// أقصى عدد بنود معروضة في اللافتة
  static const int _maxBannerItems = 3;

  /// فلتر الحالة: all / pending / active (accepted+ready) / closed (done+cancelled)
  String _statusFilter = 'all';

  /// فلتر الفرع: '' = كل الفروع
  String _branchFilter = '';

  /// لمنع النقر المزدوج على أزرار الإجراءات
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
    // تهيئة النغمة مسبقاً حتى لا تتأخر عند أول إلغاء
    AlertSound.instance.warmUp();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    AlertSound.instance.dispose();
    super.dispose();
  }

  /// اشتراك واحد على البث: يغذّي الواجهة *و* يكشف إلغاء العميل.
  void _subscribe() {
    _subscription?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    _subscription = _firebase.getFittingRoomRequestsStream().listen(
          _onRequests,
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _error = e;
              _loading = false;
            });
          },
        );
  }

  void _onRequests(List<Map<String, dynamic>> requests) {
    // الإلغاءات الجديدة من العميل (الدفعة الأولى تُسجَّل بلا تنبيه)
    final fresh =
        _cancelWatcher.scan(requests).where(_isInBranchScope).toList();

    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
      _error = null;
    });

    if (fresh.isNotEmpty) _alertCancellations(fresh);
  }

  /// نطاق التنبيه = فلتر الفرع الحالي (اختيار الموظف لفرع يحصر التنبيهات فيه)
  bool _isInBranchScope(Map<String, dynamic> request) {
    if (_branchFilter.isEmpty) return true;
    return ((request['branchId'] as String?) ?? '') == _branchFilter;
  }

  /// صوت + اهتزاز + لافتة حمراء ثابتة (لا تختفي تلقائياً — الموظف يقرّها)
  void _alertCancellations(List<Map<String, dynamic>> fresh) {
    for (final r in fresh) {
      final id = (r['id'] as String?) ?? '';
      if (id.isEmpty || _customerCancelledIds.contains(id)) continue;
      _customerCancelledIds.add(id);
      _customerCancellations.insert(0, r);
    }
    while (_customerCancellations.length > _maxBannerItems) {
      _customerCancellations.removeLast();
    }

    setState(() {});
    HapticFeedback.heavyImpact();
    AlertSound.instance.playCancellationChime(
      requestId: (fresh.first['id'] as String?) ?? '',
    );
  }

  /// إخفاء اللافتة فقط — يبقى تمييز البطاقات حتى نهاية الجلسة
  void _dismissCancellationBanner() {
    setState(() => _customerCancellations.clear());
  }

  // ==================== الإجراءات ====================

  /// نقل الطلب إلى الحالة التالية + إشعار العميل عبر Vercel (FCM)
  Future<void> _advance(
    Map<String, dynamic> request,
    String newStatus,
    String successLabel,
  ) async {
    final id = (request['id'] as String?) ?? '';
    if (id.isEmpty || _busy.contains(id)) return;

    setState(() => _busy.add(id));
    try {
      final handledBy =
          context.read<AuthProvider>().user?.id ?? '';
      await _firebase.updateFittingRoomRequestStatus(
        id,
        newStatus,
        handledBy: handledBy,
      );

      // إشعار العميل — لا يُعطّل الواجهة إن فشل
      final userId = (request['userId'] as String?) ?? '';
      int notified = 0;
      if (userId.isNotEmpty) {
        notified = await NotificationServer()
            .sendFittingRoomStatusNotification(
          userId: userId,
          productName: (request['productName'] as String?) ?? 'منتجك',
          size: (request['size'] as String?) ?? 'موحّد',
          status: newStatus,
          requestId: id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notified > 0
                ? '$successLabel — وتم إشعار العميل ✅'
                : '$successLabel ✅',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to update fitting-room request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث الطلب: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _confirmCancel(Map<String, dynamic> request) {
    final id = (request['id'] as String?) ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: Text(
            'سيتم إلغاء طلب «${request['productName'] ?? ''}» '
            'مقاس ${request['size'] ?? ''} ولن يظهر كطلب نشط.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('رجوع'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _advance(request, 'cancelled', 'تم إلغاء الطلب');
              },
              child: const Text(
                'تأكيد الإلغاء',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== أدوات عرض ====================

  String _relativeTime(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return '—';
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(epochMs),
    );
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return 'منذ ${(diff.inDays / 30).floor()} شهر';
  }

  String _clock(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _epoch(Map<String, dynamic> r, String key) =>
      (r[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات غرفة القياس 🏬'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // لافتة الإلغاء تبقى ظاهرة فوق القائمة حتى يقرّها الموظف
            if (_customerCancellations.isNotEmpty) _buildCancellationBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// لافتة حمراء ثابتة: «تم إلغاء الطلب من قبل العميل»
  Widget _buildCancellationBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.error,
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notification_important,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إلغاء من العميل — توقّف عن إحضار القطعة ⛔',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ..._customerCancellations.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${FittingRoomCancellationWatcher.cancellationMessage(r)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إخفاء التنبيه',
            onPressed: _dismissCancellationBanner,
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'تعذّر تحميل الطلبات: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final all = _requests;
    final branches = <String, String>{};
    for (final r in all) {
      final id = (r['branchId'] as String?) ?? '';
      final name = (r['branchName'] as String?) ?? '';
      if (id.isNotEmpty && name.isNotEmpty) branches[id] = name;
    }
    if (_branchFilter.isNotEmpty && !branches.containsKey(_branchFilter)) {
      _branchFilter = '';
    }

    final filtered = all.where((r) {
      final status = (r['status'] ?? 'pending') as String;
      final branch = (r['branchId'] as String?) ?? '';
      final statusOk = switch (_statusFilter) {
        'pending' => status == 'pending',
        'active' => status == 'accepted' || status == 'ready',
        'closed' => status == 'done' || status == 'cancelled',
        _ => true,
      };
      final branchOk =
          _branchFilter.isEmpty || branch == _branchFilter;
      return statusOk && branchOk;
    }).toList();

    // الأحدث أولاً (البث مرتّب مسبقاً — هذا تأكيد للحماية)
    filtered.sort((a, b) =>
        _epoch(b, 'createdAt').compareTo(_epoch(a, 'createdAt')));

    return RefreshIndicator(
      onRefresh: () async => _subscribe(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(all),
          const SizedBox(height: 16),
          _buildStatusFilters(all),
          if (branches.length > 1) ...[
            const SizedBox(height: 8),
            _buildBranchFilters(branches),
          ],
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            _buildEmptyState(all.isEmpty)
          else
            ..._buildGroupedCards(filtered, branches.length > 1),
        ],
      ),
    );
  }

  // ==================== الملخص ====================

  Widget _buildSummaryCard(List<Map<String, dynamic>> all) {
    int count(String status) =>
        all.where((r) => (r['status'] ?? 'pending') == status).length;
    final pending = count('pending');
    final active = count('accepted') + count('ready');
    final closed = count('done') + count('cancelled');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending > 0
                          ? '$pending طلب جديد بانتظار الموظفين'
                          : 'لا توجد طلبات جديدة 🎉',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$active قيد المعالجة · $closed منتهية',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryPill('جديد', pending, AppColors.warning),
              const SizedBox(width: 8),
              _buildSummaryPill('قيد المعالجة', active, AppColors.info),
              const SizedBox(width: 8),
              _buildSummaryPill('منتهية', closed, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== الفلاتر ====================

  Widget _buildStatusFilters(List<Map<String, dynamic>> all) {
    int countOf(String filter) => all.where((r) {
          final s = (r['status'] ?? 'pending') as String;
          return switch (filter) {
            'pending' => s == 'pending',
            'active' => s == 'accepted' || s == 'ready',
            'closed' => s == 'done' || s == 'cancelled',
            _ => true,
          };
        }).length;

    final filters = <String, String>{
      'all': 'الكل',
      'pending': 'جديد',
      'active': 'قيد المعالجة',
      'closed': 'منتهية',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((e) {
          final selected = _statusFilter == e.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text('${e.value} (${countOf(e.key)})'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              onSelected: (_) => setState(() => _statusFilter = e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBranchFilters(Map<String, String> branches) {
    final entries = branches.entries.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              selected: _branchFilter.isEmpty,
              label: const Text('كل الفروع'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: _branchFilter.isEmpty
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              selectedColor: AppColors.info,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              onSelected: (_) => setState(() => _branchFilter = ''),
            ),
          ),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                selected: _branchFilter == e.key,
                label: Text(e.value),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _branchFilter == e.key
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                selectedColor: AppColors.info,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                onSelected: (_) => setState(() => _branchFilter = e.key),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== القوائم ====================

  /// تجميع الطلبات حسب الفرع (عند تعدد الفروع) وإلا قائمة واحدة
  List<Widget> _buildGroupedCards(
    List<Map<String, dynamic>> requests,
    bool groupByBranch,
  ) {
    if (!groupByBranch) {
      return requests.map(_buildRequestCard).toList();
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in requests) {
      final key = (r['branchName'] as String?)?.trim().isNotEmpty == true
          ? (r['branchName'] as String)
          : 'فرع غير محدد';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final widgets = <Widget>[];
    groups.forEach((branchName, list) {
      final pending =
          list.where((r) => (r['status'] ?? 'pending') == 'pending').length;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pending > 0 ? '${list.length} · $pending جديد' : '${list.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      widgets.addAll(list.map(_buildRequestCard));
      widgets.add(const SizedBox(height: 8));
    });
    return widgets;
  }

  Widget _buildEmptyState(bool nothingAtAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.checkroom, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            nothingAtAll
                ? 'لا توجد طلبات غرفة قياس حتى الآن'
                : 'لا توجد طلبات مطابقة للفلتر الحالي',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== بطاقة الطلب ====================

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending') as String;
    final style = _styleOf(status);
    final id = (r['id'] as String?) ?? '';
    final isBusy = _busy.contains(id);
    final image = (r['productImage'] as String?) ?? '';
    final size = (r['size'] as String?) ?? '';
    final color = (r['color'] as String?) ?? '';
    final sessionId = (r['sessionId'] as String?) ?? '';
    final note = (r['note'] as String?) ?? '';
    final createdAt = _epoch(r, 'createdAt');
    // ألغاه العميل في هذه الجلسة؟ → إبراز أحمر + وسم تحذيري
    final customerCancelled = _customerCancelledIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customerCancelled
              ? AppColors.error
              : style.color.withValues(alpha: 0.35),
          width: customerCancelled ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة المنتج (تُخزَّن في الطلب نفسه — لا استعلام إضافي)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: image.isNotEmpty
                    ? AppImage(
                        imageUrl: image,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        backgroundColor: AppColors.accentLight,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: AppColors.accentLight,
                        child: const Icon(Icons.checkroom,
                            size: 26, color: AppColors.textSecondary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (r['productName'] as String?) ?? 'منتج',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (customerCancelled)
                          _buildChip('ألغى العميل الطلب ⛔', AppColors.error),
                        if (size.isNotEmpty) _buildChip('المقاس $size',
                            AppColors.primary),
                        if (color.isNotEmpty)
                          _buildChip('اللون $color', AppColors.info),
                        _buildChip('${_relativeTime(createdAt)} · ${_clock(createdAt)}',
                            AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // شارة الحالة
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: style.color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 13, color: style.color),
                    const SizedBox(width: 4),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sessionId.isNotEmpty || note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (sessionId.isNotEmpty)
                  Text(
                    'الجلسة: $sessionId',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (sessionId.isNotEmpty && note.isNotEmpty)
                  const SizedBox(width: 10),
                if (note.isNotEmpty)
                  Expanded(
                    child: Text(
                      'ملاحظة: $note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _buildActions(r, status, isBusy),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// أزرار الإجراءات حسب حالة الطلب (مسار العمل داخل الفرع)
  Widget _buildActions(
    Map<String, dynamic> request,
    String status,
    bool isBusy,
  ) {
    if (isBusy) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final buttons = <Widget>[];

    switch (status) {
      case 'pending':
        buttons.add(_actionButton(
          label: 'قبول الطلب',
          icon: Icons.play_arrow_rounded,
          color: AppColors.info,
          filled: true,
          onTap: () => _advance(request, 'accepted', 'تم قبول الطلب'),
        ));
        break;
      case 'accepted':
        buttons.add(_actionButton(
          label: 'وصلت غرفة القياس',
          icon: Icons.checkroom,
          color: AppColors.success,
          filled: true,
          onTap: () => _advance(request, 'ready', 'الطلب الآن في غرفة القياس'),
        ));
        break;
      case 'ready':
        buttons.add(_actionButton(
          label: 'تم التسليم',
          icon: Icons.verified,
          color: AppColors.success,
          filled: true,
          onTap: () => _advance(request, 'done', 'تم تسليم الطلب'),
        ));
        break;
      default:
        buttons.add(Expanded(
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status == 'cancelled'
                  ? 'تم إلغاء الطلب'
                  : 'اكتمل الطلب — لا إجراءات',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ));
    }

    if (status != 'done' && status != 'cancelled') {
      buttons.add(const SizedBox(width: 8));
      buttons.add(_actionButton(
        label: 'إلغاء',
        icon: Icons.close,
        color: AppColors.error,
        filled: false,
        onTap: () => _confirmCancel(request),
      ));
    }

    return Row(children: buttons);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    if (filled) {
      return Expanded(
        child: SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
