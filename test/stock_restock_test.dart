import 'package:flutter_test/flutter_test.dart';
import 'package:alafif_newform/services/stock_restock.dart';

void main() {
  group('computeRestock — منتج بمقاسات', () {
    test('يُرجِع للمقاس نفسه ويزيد الإجمالي', () {
      final plan = computeRestock(
        productName: 'قميص',
        stockVariants: {'48': 5, '50': 2},
        stockQuantity: 7,
        restoreBySize: {'48': 2},
        restoreTotal: 2,
      );
      expect(plan.tracked, isTrue);
      expect(plan.stockVariants['48'], 7);
      expect(plan.stockVariants['50'], 2);
      expect(plan.stockQuantity, 9);
      expect(plan.restoredPieces, 2);
      expect(plan.warnings, isEmpty);
    });

    test('مقاس غير موجود → تحذير بلا انهيار', () {
      final plan = computeRestock(
        productName: 'قميص',
        stockVariants: {'48': 5},
        stockQuantity: 5,
        restoreBySize: {'52': 1},
        restoreTotal: 1,
      );
      expect(plan.restoredPieces, 0);
      expect(plan.stockQuantity, isNull);
      expect(plan.stockVariants, isEmpty);
      expect(plan.warnings.single, contains('52'));
    });

    test('إجمالي صفر مع مقاسات → يزيد المقاس فقط (يعكس الخصم)', () {
      final plan = computeRestock(
        productName: 'قميص',
        stockVariants: {'48': 3},
        stockQuantity: 0,
        restoreBySize: {'48': 1},
        restoreTotal: 1,
      );
      expect(plan.stockVariants['48'], 4);
      expect(plan.stockQuantity, isNull);
      expect(plan.restoredPieces, 1);
    });

    test('عدة مقاسات في طلب واحد', () {
      final plan = computeRestock(
        productName: 'قميص',
        stockVariants: {'48': 1, '50': 1},
        stockQuantity: 2,
        restoreBySize: {'48': 2, '50': 1},
        restoreTotal: 3,
      );
      expect(plan.stockVariants['48'], 3);
      expect(plan.stockVariants['50'], 2);
      expect(plan.stockQuantity, 5);
      expect(plan.restoredPieces, 3);
    });
  });

  group('computeRestock — بلا مقاسات', () {
    test('يزيد الكمية الكلية', () {
      final plan = computeRestock(
        productName: 'حزام',
        stockVariants: {},
        stockQuantity: 10,
        restoreBySize: {},
        restoreTotal: 2,
      );
      expect(plan.tracked, isTrue);
      expect(plan.stockQuantity, 12);
      expect(plan.restoredPieces, 2);
    });

    test('مخزون غير مُتتبَّع (صفر بلا مقاسات) → لا إرجاع', () {
      final plan = computeRestock(
        productName: 'حزام',
        stockVariants: {},
        stockQuantity: 0,
        restoreBySize: {},
        restoreTotal: 3,
      );
      expect(plan.tracked, isFalse);
      expect(plan.restoredPieces, 0);
      expect(plan.stockQuantity, isNull);
    });
  });
}
