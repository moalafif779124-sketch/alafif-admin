// إرجاع المخزون عند إلغاء طلب — دالة نقية (بلا Firestore) كي تُختبر وحدها.
//
// تعكس بالضبط منطق الخصم في تطبيق العميل (`stock_calculator.dart`):
//  * المنتج له مقاسات (stockVariants غير فارغة) → الإرجاع إلى مخزون المقاس نفسه،
//    وإن كانت الكمية الكلية > 0 فتُزاد أيضاً بنفس العدد (كما خُصمت منه).
//  * لا مقاسات و stockQuantity > 0 → الإرجاع إلى الكمية الكلية فقط.
//  * الاثنان صفر/فارغ → مخزون غير مُتتبَّع: لم يُخصم شيء وقت الطلب فلا يُرجَع شيء.
//
// لا ترمي هذه الدالة أبداً: الإرجاع عملية إنقاذ، وأي سطر غير قابل للإرجاع
// يُسجَّل في [RestockPlan.warnings] ويُتخطّى (منتج محذوف/مقاس غير معروف).

class RestockPlan {
  /// الكمية الجديدة المراد كتابتها. null = لا تغيير.
  final int? stockQuantity;
  /// المقاسات الجديدة. فارغة = لا تغيير.
  final Map<String, int> stockVariants;

  /// هل المنتج مُتتبَّع؟ غير المتتبَّع لا يُكتب له شيء.
  final bool tracked;

  /// عدد القطع التي أُرجعت فعلاً (للعرض للمسؤول).
  final int restoredPieces;

  /// أسطر لم تُرجَع ولماذا (تظهر في ملخص العملية).
  final List<String> warnings;

  const RestockPlan({
    required this.stockQuantity,
    required this.stockVariants,
    required this.tracked,
    required this.restoredPieces,
    required this.warnings,
  });
}

RestockPlan computeRestock({
  required String productName,
  required Map<String, int> stockVariants,
  required int stockQuantity,
  required Map<String, int> restoreBySize,
  required int restoreTotal,
}) {
  final variants = Map<String, int>.from(stockVariants);
  final warnings = <String>[];
  final tracked = variants.isNotEmpty || stockQuantity > 0;

  if (!tracked) {
    return const RestockPlan(
      stockQuantity: null,
      stockVariants: {},
      tracked: false,
      restoredPieces: 0,
      warnings: [],
    );
  }

  if (variants.isNotEmpty) {
    var restored = 0;
    for (final entry in restoreBySize.entries) {
      if (!variants.containsKey(entry.key)) {
        warnings.add('«$productName»: المقاس ${entry.key} لم يعد موجوداً — لم يُرجَع');
        continue;
      }
      variants[entry.key] = (variants[entry.key] ?? 0) + entry.value;
      restored += entry.value;
    }
    var newTotal = stockQuantity;
    if (newTotal > 0 && restored > 0) {
      newTotal += restored;
    }
    if (restored == 0) {
      // لا شيء أُرجع فعلاً (كل المقاسات غير معروفة) — لا نكتب حقلاً بلا داعٍ.
      return RestockPlan(
        stockQuantity: null,
        stockVariants: const {},
        tracked: true,
        restoredPieces: 0,
        warnings: warnings,
      );
    }
    return RestockPlan(
      stockQuantity: nullIfUnchanged(newTotal, stockQuantity),
      stockVariants: variants,
      tracked: true,
      restoredPieces: restored,
      warnings: warnings,
    );
  }

  // بلا مقاسات → إرجاع الكمية الكلية
  return RestockPlan(
    stockQuantity: stockQuantity + restoreTotal,
    stockVariants: variants,
    tracked: true,
    restoredPieces: restoreTotal,
    warnings: warnings,
  );
}

/// يعيد null إذا لم تتغير القيمة (كي لا نكتب حقلاً بلا داعٍ).
int? nullIfUnchanged(int next, int prev) => next == prev ? null : next;
