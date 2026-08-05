/// نموذج التقييم والمراجعة
class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final String fitFeedback; // "مناسب تماماً" / "صغير" / "كبير"
  final String photoBase64; // صورة اختيارية (مضغوطة)
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.fitFeedback = '',
    this.photoBase64 = '',
    required this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      rating: (map['rating'] ?? 5).toDouble(),
      comment: map['comment'] ?? '',
      fitFeedback: map['fitFeedback'] ?? '',
      photoBase64: map['photoBase64'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'fitFeedback': fitFeedback,
      'photoBase64': photoBase64,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
