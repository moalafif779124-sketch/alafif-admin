import 'product.dart';

/// نموذج عنصر في سلة التسوق
class CartItem {
  final String id;
  final Product product;
  final String size;
  final String color;
  final String colorHex;
  int quantity;

  CartItem({
    required this.id,
    required this.product,
    required this.size,
    required this.color,
    this.colorHex = '#000000',
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  double get totalEffectivePrice => product.effectivePrice * quantity;

  factory CartItem.fromMap(Map<String, dynamic> map, Product product) {
    return CartItem(
      id: map['id'] ?? '',
      product: product,
      size: map['size'] ?? '',
      color: map['color'] ?? '',
      colorHex: map['colorHex'] ?? '#000000',
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': product.id,
      'size': size,
      'color': color,
      'colorHex': colorHex,
      'quantity': quantity,
    };
  }
}
