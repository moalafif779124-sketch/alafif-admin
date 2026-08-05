import 'package:flutter/foundation.dart';
import '../models/review.dart';
import '../services/firebase_service.dart';

/// مزود حالة التقييمات والمراجعات
class ReviewProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;
  bool _hasReviewed = false;
  double _averageRating = 0;
  int _reviewCount = 0;

  List<Review> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReviewed => _hasReviewed;
  double get averageRating => _averageRating;
  int get reviewCount => _reviewCount;

  /// جلب مراجعات منتج
  Future<void> loadReviews(String productId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _firebaseService.getProductReviews(productId);
      _reviews = data.map((m) => Review.fromMap(m)).toList();
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل التقييمات';
      debugPrint('Error loading reviews: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// إضافة مراجعة جديدة — مع ملاءمة المقاس وصورة اختيارية
  Future<bool> addReview({
    required String productId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
    String fitFeedback = '',
    String photoBase64 = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.addReview({
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'fitFeedback': fitFeedback,
        'photoBase64': photoBase64,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      _hasReviewed = true;
      _isLoading = false;
      notifyListeners();

      // إعادة تحميل المراجعات
      await loadReviews(productId);
      return true;
    } catch (e) {
      _error = 'فشل إضافة التقييم';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// التحقق مما إذا كان المستخدم قد قيّم المنتج
  Future<void> checkUserReviewed(String productId, String userId) async {
    try {
      _hasReviewed = await _firebaseService.hasUserReviewed(productId, userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking review: $e');
    }
  }

  /// مسح الأخطاء
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
