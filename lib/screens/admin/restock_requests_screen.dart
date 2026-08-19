import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_image.dart';

/// شاشة إدارة طلبات توفر المخزن — تعرض المنتجات/المقاسات المطلوبة
/// مع إمكانية تحديدها كمُتوفرة (resolved)
class RestockRequestsScreen extends StatefulWidget {
  const RestockRequestsScreen({super.key});

  @override
  State<RestockRequestsScreen> createState() => _RestockRequestsScreenState();
}

class _RestockRequestsScreenState extends State<RestockRequestsScreen> {
  final FirebaseService _firebase = FirebaseService();
  Stream<List<Map<String, dynamic>>>? _requestsStream;
  final Map<String, String> _productImages = {}; // productId -> first image

  @override
  void initState() {
    super.initState();
    _requestsStream = _firebase.getRestockRequestsStream();
    _loadProductImages();
  }

  /// جلب صور المنتجات لربطها ببطاقات الطلبات
  Future<void> _loadProductImages() async {
    try {
      final result = await _firebase.getProducts(limit: 500);
      if (!mounted) return;
      final products = List<Map<String, dynamic>>.from(result['products'] ?? []);
      setState(() {
        for (final p in products) {
          final images = (p['images'] as List<dynamic>?) ?? [];
          if (images.isNotEmpty) {
            _productImages[p['id']] = images.first as String;
          }
        }
      });
    } catch (_) {
      // الصور غير متوفرة — تُعرض أيقونة افتراضية بدلاً منها
    }
  }

  /// تحديث حالة مجموعة طلبات إلى resolved (كل الطلبات المعلّقة للمجموعة)
  Future<void> _markGroupResolved(List<Map<String, dynamic>> requests) async {
    final pending = requests.where((r) => (r['status'] ?? 'pending') == 'pending').toList();
    if (pending.isEmpty) return;
    try {
      for (final r in pending) {
        await _firebase.markRestockResolved(r['id']);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديد ${pending.length} طلب كمُتوفّر ✅'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to resolve restock requests: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التحديث: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(int? epochMs) {
    if (epochMs == null || epochMs <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات التوفر 🔔'),
          centerTitle: true,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requestsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ في تحميل الطلبات: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data!;
            if (requests.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'لا توجد طلبات توفر حالياً',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ===== تجميع حسب productId + requestedSize =====
            final pendingGroups = <String, List<Map<String, dynamic>>>{};
            final resolvedGroups = <String, List<Map<String, dynamic>>>{};
            for (final r in requests) {
              final status = r['status'] ?? 'pending';
              final key =
                  '${r['productId']}|${r['requestedSize']}';
              if (status == 'pending') {
                pendingGroups.putIfAbsent(key, () => []).add(r);
              } else {
                resolvedGroups.putIfAbsent(key, () => []).add(r);
              }
            }

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ===== الملخص =====
                  _buildSummaryCard(pendingGroups, resolvedGroups),
                  const SizedBox(height: 20),

                  // ===== طلبات معلّقة =====
                  if (pendingGroups.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'طلبات معلّقة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingGroups.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...pendingGroups.entries
                        .map((e) => _buildGroupCard(e.key, e.value)),
                  ],

                  if (pendingGroups.isNotEmpty && resolvedGroups.isNotEmpty)
                    const SizedBox(height: 24),

                  // ===== طلبات مُنجزة =====
                  if (resolvedGroups.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'طلبات مُنجزة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${resolvedGroups.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...resolvedGroups.entries
                        .map((e) => _buildGroupCard(e.key, e.value)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================= بطاقة الملخص =======================

  Widget _buildSummaryCard(
    Map<String, List<Map<String, dynamic>>> pending,
    Map<String, List<Map<String, dynamic>>> resolved,
  ) {
    final totalPending = pending.values.fold<int>(0, (s, l) => s + l.length);
    final totalResolved = resolved.values.fold<int>(0, (s, l) => s + l.length);

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
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalPending > 0
                      ? '$totalPending طلب توفر بانتظار المعالجة'
                      : 'لا توجد طلبات معلّقة 🎉',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalResolved طلب مُنجز سابقاً',
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
    );
  }

  // ======================= بطاقة مجموعة طلب =======================

  Widget _buildGroupCard(String key, List<Map<String, dynamic>> requests) {
    final first = requests.first;
    final productName = first['productName'] as String? ?? 'منتج';
    final size = first['requestedSize'] as String? ?? '';
    final productId = first['productId'] as String? ?? '';
    final isPending = (first['status'] ?? 'pending') == 'pending';
    final count = requests.length;
    final image = _productImages[productId] ?? '';
    // آخر طلب في المجموعة (الأحدث)
    final latestDate = _formatDate(
      requests.map((r) => (r['createdAt'] as num?)?.toInt() ?? 0).reduce(
          (a, b) => a > b ? a : b),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // ===== الصورة =====
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.isNotEmpty
                ? AppImage(
                    imageUrl: image,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    backgroundColor: AppColors.accentLight,
                  )
                : Container(
                    width: 52,
                    height: 52,
                    color: AppColors.accentLight,
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 24, color: AppColors.textSecondary),
                  ),
          ),
          const SizedBox(width: 12),

          // ===== المعلومات =====
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isPending
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    decoration: isPending
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // المقاس — بارز
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPending
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        'المقاس $size',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count طلبات',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'آخر طلب: $latestDate',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ===== الإجراء =====
          if (isPending)
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _markGroupResolved(requests),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text(
                  'تحديث وتوفر ✅',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            )
          else
            const Icon(Icons.verified,
                color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
