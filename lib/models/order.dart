/// نموذج الطلب
class Order {
  final String id;
  final String userId;
  final String orderNumber;
  final List<OrderItem> items;
  final String status;
  final double subtotal;
  final double shippingCost;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentReference;
  final AddressInfo shippingAddress;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.items,
    required this.status,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    this.discount = 0,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference,
    required this.shippingAddress,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
  });

  String get statusText {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'confirmed':
        return 'تم التأكيد';
      case 'processing':
        return 'قيد التجهيز';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التوصيل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String get paymentStatusText {
    switch (paymentStatus) {
      case 'pending':
        return 'في انتظار الدفع';
      case 'paid':
        return 'تم الدفع';
      case 'failed':
        return 'فشل الدفع';
      case 'refunded':
        return 'تم الاسترجاع';
      default:
        return paymentStatus;
    }
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e))
              .toList() ??
          [],
      status: map['status'] ?? 'pending',
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      shippingCost: (map['shippingCost'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentReference: map['paymentReference'],
      shippingAddress: AddressInfo.fromMap(map['shippingAddress'] ?? {}),
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deliveredAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status,
      'subtotal': subtotal,
      'shippingCost': shippingCost,
      'tax': tax,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'shippingAddress': shippingAddress.toMap(),
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'deliveredAt': deliveredAt?.millisecondsSinceEpoch,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final String productImage;
  final String size;
  final String color;
  final double price;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.size,
    required this.color,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      size: map['size'] ?? '',
      color: map['color'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'size': size,
      'color': color,
      'price': price,
      'quantity': quantity,
    };
  }
}

class AddressInfo {
  final String fullName;
  final String phone;
  final String fullAddress;
  final String? landmark;

  AddressInfo({
    required this.fullName,
    required this.phone,
    required this.fullAddress,
    this.landmark,
  });

  factory AddressInfo.fromMap(Map<String, dynamic> map) {
    return AddressInfo(
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      fullAddress: map['fullAddress'] ?? '',
      landmark: map['landmark'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'fullAddress': fullAddress,
      'landmark': landmark,
    };
  }
}
