import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/order.dart';
import '../../widgets/app_image.dart';

/// شاشة إدارة الطلبات
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final FirebaseService _firebase = FirebaseService();

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'confirmed':
        return 'تم الاعتماد';
      case 'processing':
        return 'قيد التجهيز';
      case 'shipped':
        return 'في الطريق';
      case 'delivered':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.verified_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'kuraimi':
        return 'كريمي باي';
      case 'jeeb':
        return 'جيب';
      case 'cod':
        return 'الدفع عند الاستلام';
      default:
        return method;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestamp is int ? timestamp : (timestamp as double).toInt(),
    );
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOrderDetails(Map<String, dynamic> orderData) {
    final order = Order.fromMap(orderData);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // مؤشر السحب
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // المحتوى
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // رأس الطلب
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(order.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusColor(order.status).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(order.status),
                                size: 16,
                                color: _statusColor(order.status),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                order.statusText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(order.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(orderData['createdAt']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    // معلومات العميل
                    const Text(
                      'معلومات العميل',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.person, 'الاسم', order.shippingAddress.fullName),
                    _infoRow(Icons.phone, 'الهاتف', order.shippingAddress.phone),
                    _infoRow(Icons.location_on, 'العنوان', order.shippingAddress.fullAddress),
                    if (order.shippingAddress.landmark != null &&
                        order.shippingAddress.landmark!.isNotEmpty)
                      _infoRow(Icons.location_city, 'معلم', order.shippingAddress.landmark!),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    // معلومات الدفع
                    const Text(
                      'معلومات الدفع',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.payment,
                      'طريقة الدفع',
                      _paymentMethodLabel(order.paymentMethod),
                    ),
                    _infoRow(
                      Icons.account_balance_wallet,
                      'حالة الدفع',
                      order.paymentStatusText,
                    ),
                    if (order.paymentReference != null)
                      _infoRow(
                        Icons.receipt,
                        'مرجع الدفع',
                        order.paymentReference!,
                      ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    // منتجات الطلب
                    const Text(
                      'المنتجات',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: item.productImage.isNotEmpty
                                    ? AppImage(
                                        imageUrl: item.productImage,
                                        fit: BoxFit.cover,
                                        backgroundColor: AppColors.accentLight,
                                      )
                                    : Container(
                                        color: AppColors.accentLight,
                                        child: Icon(
                                          Icons.image_outlined,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (item.size.isNotEmpty)
                                        Text(
                                          'المقاس: ${item.size}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      if (item.size.isNotEmpty && item.color.isNotEmpty)
                                        const Text(' | '),
                                      if (item.color.isNotEmpty)
                                        Text(
                                          'اللون: ${item.color}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'العدد: ${item.quantity}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${AppConstants.currency}${item.total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 16),
                      const Text(
                        'ملاحظات',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          order.notes!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 16),

                    // إجمالي الطلب
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المجموع الفرعي',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${AppConstants.currency}${order.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الشحن',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${AppConstants.currency}${order.shippingCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (order.discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الخصم',
                            style: TextStyle(fontSize: 13, color: AppColors.success),
                          ),
                          Text(
                            '-${AppConstants.currency}${order.discount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الضريبة',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${AppConstants.currency}${order.tax.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${AppConstants.currency}${order.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ===== إرسال للسائق عبر الواتساب =====
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _dispatchToDriver(orderData),
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: const Text(
                          'إرسال للسائق عبر الواتساب',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يرسل تفاصيل التوصيل والتحصيل إلى رقم الواتساب الخاص بالمتجر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // تغيير الحالة
                    const Text(
                      'تغيير الحالة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled']
                        .map(
                          (status) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton.icon(
                              onPressed: order.status == status
                                  ? null
                                  : () => _updateOrderStatus(order.id, status),
                              icon: Icon(
                                _statusIcon(status),
                                size: 18,
                                color: order.status == status
                                    ? AppColors.textSecondary
                                    : _statusColor(status),
                              ),
                              label: Text(
                                _statusText(status),
                                style: TextStyle(
                                  color: order.status == status
                                      ? AppColors.textSecondary
                                      : _statusColor(status),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: order.status == status
                                      ? AppColors.border
                                      : _statusColor(status).withValues(alpha: 0.5),
                                  width: order.status == status ? 1 : 1.5,
                                ),
                                backgroundColor: order.status == status
                                    ? AppColors.background
                                    : _statusColor(status).withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                minimumSize: const Size(double.infinity, 44),
                              ),
                            ),
                          ),
                        ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    Navigator.of(context).pop(); // إغلاق البوتوم شيت
    try {
      await _firebase.updateOrderStatus(orderId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب إلى "${_statusText(newStatus)}"'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الحالة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// إرسال تفاصيل الطلب للسائق عبر الواتساب
  Future<void> _dispatchToDriver(Map<String, dynamic> orderData) async {
    final order = Order.fromMap(orderData);
    final orderId = orderData['id'] ?? order.id;
    final customerName = order.shippingAddress.fullName;
    // بيانات التوصيل الإقليمي (من الحقول الجديدة مع بدائل آمنة)
    final recipientPhone = (orderData['recipientPhone'] as String?) ??
        order.shippingAddress.phone;
    final city = (orderData['city'] as String?) ?? '';
    final nearestLandmark = (orderData['nearestLandmark'] as String?) ??
        (order.shippingAddress.landmark ?? '—');
    final streetAddress = (orderData['streetAddress'] as String?) ??
        order.shippingAddress.fullAddress;
    final totalAmount = order.total.toStringAsFixed(0);

    final message = Uri.encodeComponent(
      '📦 طلب جديد للتوصيل: #$orderId\n'
      '👤 العميل: $customerName\n'
      '📞 الهاتف: $recipientPhone\n'
      '📍 المدينة: $city\n'
      '🏢 المعلم: $nearestLandmark\n'
      '🏠 العنوان: $streetAddress\n'
      '💰 المبلغ المطلوب تحصيله (COD): $totalAmount YER',
    );
    final phone = AppConstants.companyWhatsApp
        .replaceFirst('https://wa.me/', '')
        .trim();
    final url = 'https://wa.me/$phone?text=$message';
    try {
      final launched = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الواتساب — تأكد من تثبيته'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ WhatsApp dispatch error: $e');
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الطلبات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firebase.getAllOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل الطلبات...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: AppColors.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'حدث خطأ أثناء تحميل الطلبات',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {}); // إعادة تحميل الـ Stream
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 100,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد طلبات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'سيتم عرض الطلبات هنا عند ورودها',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {}); // RefreshIndicator يعيد تعشيق Stream
              },
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // ===== لوحة كانبان: أعمدة حسب حالة الطلب =====
                    SizedBox(
                      height: constraints.maxHeight - 24,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          ..._kanbanStatuses.map(
                            (s) => _buildKanbanColumn(
                                orders, s.$1, s.$2, s.$3, s.$4),
                          ),
                          _buildKanbanColumn(
                            orders,
                            'cancelled',
                            'ملغي',
                            Icons.cancel_outlined,
                            AppColors.error,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================== لوحة كانبان ========================

  /// مسار الحالات: قيد المراجعة ← تم الاعتماد ← قيد التجهيز ← في الطريق ← مكتمل
  static const List<(String, String, IconData, Color)> _kanbanStatuses = [
    ('pending', 'قيد المراجعة', Icons.schedule, Color(0xFFFFB300)),
    ('confirmed', 'تم الاعتماد', Icons.check_circle_outline, Color(0xFF2196F3)),
    ('processing', 'قيد التجهيز', Icons.inventory_2_outlined, Color(0xFFFF9800)),
    ('shipped', 'في الطريق', Icons.local_shipping_outlined, Color(0xFF9C27B0)),
    ('delivered', 'مكتمل', Icons.verified_outlined, Color(0xFF4CAF50)),
  ];

  /// الحالة التالية في المسار (null = الحالة النهائية)
  String? _nextStatus(String status) {
    switch (status) {
      case 'pending':
        return 'confirmed';
      case 'confirmed':
        return 'processing';
      case 'processing':
        return 'shipped';
      case 'shipped':
        return 'delivered';
      default:
        return null; // delivered / cancelled
    }
  }

  /// تقدم الطلب خطوة واحدة في المسار — كتابة مباشرة لحقل status في Firestore
  Future<void> _advanceOrderStatus(Map<String, dynamic> orderData) async {
    final orderId = orderData['id'] ?? '';
    final current = orderData['status'] as String? ?? 'pending';
    final next = _nextStatus(current);
    if (next == null || orderId.isEmpty) return;

    try {
      await _firebase.updateOrderStatus(orderId, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نقل الطلب إلى "${_statusText(next)}" ✓'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الحالة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildKanbanColumn(
    List<Map<String, dynamic>> allOrders,
    String status,
    String label,
    IconData icon,
    Color color,
  ) {
    final columnOrders = allOrders
        .where((o) => (o['status'] as String? ?? 'pending') == status)
        .toList();

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس العمود
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${columnOrders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // بطاقات الطلبات في العمود
          Expanded(
            child: columnOrders.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 28,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 6),
                        Text(
                          'لا توجد طلبات',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: columnOrders.length,
                    itemBuilder: (_, i) =>
                        _buildKanbanCard(columnOrders[i], status, color),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(
      Map<String, dynamic> orderData, String status, Color color) {
    final orderId = orderData['id'] ?? '';
    final orderNumber =
        orderData['orderNumber'] as String? ?? '#' + orderId;
    final total = (orderData['total'] ?? 0).toDouble();
    final createdAt = orderData['createdAt'];
    final customerName = orderData['shippingAddress'] != null
        ? (orderData['shippingAddress']['fullName'] as String? ?? '')
        : '';
    final itemCount = (orderData['items'] as List?)?.length ?? 0;
    final next = _nextStatus(status);
    final isFinal = next == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(orderData),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${total.toStringAsFixed(0)} YER',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (itemCount > 0)
                    Text(
                      '$itemCount منتج',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // زر التقدم / حالة نهائية
              SizedBox(
                width: double.infinity,
                height: 34,
                child: isFinal
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'delivered' ? 'مكتمل ✓' : 'ملغي',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _advanceOrderStatus(orderData),
                        icon: const Icon(Icons.arrow_forward, size: 15),
                        label: Text(
                          'نقل إلى ${_statusText(next)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData) {
    final orderId = orderData['id'] ?? '';
    final orderNumber = orderData['orderNumber'] as String? ?? '#' + orderId;
    final status = orderData['status'] as String? ?? 'pending';
    final total = (orderData['total'] ?? 0).toDouble();
    final createdAt = orderData['createdAt'];
    final customerName = orderData['shippingAddress'] != null
        ? (orderData['shippingAddress']['fullName'] as String? ?? '')
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetails(orderData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // السطر الأول: رقم الطلب + الحالة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 18,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        orderNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(status),
                          size: 14,
                          color: _statusColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // السطر الثاني: العميل + المبلغ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customerName.isNotEmpty ? customerName : 'عميل',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppConstants.currency}${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // التاريخ
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
