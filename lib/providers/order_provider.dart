import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../services/firebase_service.dart';
import '../services/payment_service.dart';
import '../config/constants.dart';

/// مزود حالة الطلبات
class OrderProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final PaymentService _paymentService = PaymentService();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get orderCount => _orders.length;

  // =================== تحميل الطلبات ===================

  Future<void> loadOrders(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final ordersData = await _firebaseService.getUserOrders(userId);
      _orders = ordersData.map((data) => Order.fromMap(data)).toList();
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل الطلبات';
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // =================== إنشاء طلب جديد ===================

  Future<String?> createOrder({
    required String userId,
    required List<CartItem> cartItems,
    required String paymentMethod,
    required Map<String, dynamic> shippingAddress,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // حساب المجموع
      final subtotal = cartItems.fold<double>(
          0, (sum, item) => sum + (item.product.price * item.quantity));
      final tax = subtotal * AppConstants.taxRate;
      final total = subtotal + tax + AppConstants.shippingCost;

      // إنشاء رقم طلب
      final orderNumber = 'ANF-${DateTime.now().millisecondsSinceEpoch}';

      // تحضير بيانات الطلب
      final orderData = Order(
        id: '', // سيتم تعيينه من Firestore
        userId: userId,
        orderNumber: orderNumber,
        items: cartItems
            .map((item) => OrderItem(
                  productId: item.product.id,
                  productName: item.product.name,
                  productImage:
                      item.product.images.isNotEmpty ? item.product.images.first : '',
                  size: item.size,
                  color: item.color,
                  price: item.product.price,
                  quantity: item.quantity,
                ))
            .toList(),
        status: 'pending',
        subtotal: subtotal,
        shippingCost: AppConstants.shippingCost,
        tax: tax,
        total: total,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod == 'cod' ? 'pending' : 'pending',
        shippingAddress: AddressInfo(
          fullName: shippingAddress['fullName'] ?? '',
          phone: shippingAddress['phone'] ?? '',
          fullAddress: shippingAddress['fullAddress'] ?? '',
          landmark: shippingAddress['landmark'],
        ),
        notes: notes,
        createdAt: DateTime.now(),
      );

      // حفظ الطلب في Firebase
      final orderId = await _firebaseService.createOrder(orderData.toMap());

      // معالجة الدفع
      final paymentResult = await _paymentService.processPayment(
        method: paymentMethod,
        amount: total,
        orderId: orderId,
        customerPhone: shippingAddress['phone'] ?? '',
        customerName: shippingAddress['fullName'] ?? '',
      );

      // تحديث حالة الدفع
      if (paymentResult['success'] == true) {
        await _firebaseService.firestore
            .collection('orders')
            .doc(orderId)
            .update({
          'paymentStatus': 'paid',
          'paymentReference': paymentResult['transaction_id'],
          'status': 'confirmed',
        });
      }

      // إضافة الطلب إلى القائمة المحلية
      final savedOrder = await _firebaseService.getUserOrders(userId);
      _orders = savedOrder.map((data) => Order.fromMap(data)).toList();

      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _error = 'فشل إنشاء الطلب: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // =================== إلغاء الطلب ===================

  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firebaseService.firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        final oldOrder = _orders[index];
        _orders[index] = Order(
          id: oldOrder.id,
          userId: oldOrder.userId,
          orderNumber: oldOrder.orderNumber,
          items: oldOrder.items,
          status: 'cancelled',
          subtotal: oldOrder.subtotal,
          shippingCost: oldOrder.shippingCost,
          tax: oldOrder.tax,
          discount: oldOrder.discount,
          total: oldOrder.total,
          paymentMethod: oldOrder.paymentMethod,
          paymentStatus: oldOrder.paymentStatus,
          paymentReference: oldOrder.paymentReference,
          shippingAddress: oldOrder.shippingAddress,
          notes: oldOrder.notes,
          createdAt: oldOrder.createdAt,
          updatedAt: DateTime.now(),
          deliveredAt: oldOrder.deliveredAt,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'فشل إلغاء الطلب';
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  // =================== مسح الأخطاء ===================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
