import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/firebase_service.dart';
import '../config/constants.dart';

/// مزود حالة سلة التسوق
class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _userId;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get totalEffectiveSubtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalEffectivePrice);

  double get tax => subtotal * AppConstants.taxRate;
  double get shipping => subtotal >= 50000 ? 0 : AppConstants.shippingCost;

  double get total => subtotal + tax + shipping;

  bool get hasItems => _items.isNotEmpty;

  // =================== إدارة العناصر ===================

  void addItem(CartItem item) {
    final index = _items.indexWhere(
      (i) => i.product.id == item.product.id && i.size == item.size && i.color == item.color,
    );

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      _saveToLocal();
      _syncToFirebase();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  int getProductQuantity(String productId) {
    return _items
        .where((item) => item.product.id == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  // =================== المزامنة ===================

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadFromFirebase();
    } else {
      _loadFromLocal();
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = _items.map((item) => {
        'id': item.id,
        'productId': item.product.id,
        'size': item.size,
        'color': item.color,
        'colorHex': item.colorHex,
        'quantity': item.quantity,
      }).toList();
      await prefs.setString('cart_items', jsonEncode(itemsJson));
    } catch (e) {
      debugPrint('Error saving cart to local: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null) {
        final itemsList = jsonDecode(cartJson) as List;
        // Note: products need to be loaded separately
        // This is a simplified version
      }
    } catch (e) {
      debugPrint('Error loading cart from local: $e');
    }
  }

  Future<void> _syncToFirebase() async {
    if (_userId == null) return;
    try {
      final service = FirebaseService();
      if (service.isInitialized) {
        await service.saveCart(
          _userId!,
          _items.map((item) => item.toMap()).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error syncing cart to Firebase: $e');
    }
  }

  Future<void> _loadFromFirebase() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final service = FirebaseService();
      if (service.isInitialized) {
        final cartData = await service.getCart(_userId!);
        if (cartData != null) {
          // Load products for each cart item
          for (final itemData in cartData) {
            final productData = await service.getProduct(itemData['productId']);
            if (productData != null) {
              final product = Product.fromMap(productData);
              final item = CartItem(
                id: itemData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                product: product,
                size: itemData['size'] ?? '',
                color: itemData['color'] ?? '',
                colorHex: itemData['colorHex'] ?? '#000000',
                quantity: itemData['quantity'] ?? 1,
              );
              _items.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cart from Firebase: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
