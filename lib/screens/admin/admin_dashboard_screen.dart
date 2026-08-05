import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import 'admin_products_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_users_screen.dart';
import 'tab_management_screen.dart';
import 'admin_flash_sale_screen.dart';

/// لوحة تحكم المدير — الصفحة الرئيسية للإدارة
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseService _firebase = FirebaseService();

  int _productCount = 0;
  int _orderCount = 0;
  int _categoryCount = 0;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // ===== استعلامات متوازية — كل استدعاءات Firestore تنفذ في نفس الوقت =====
      final results = await Future.wait([
        _firebase.getAllProducts(),
        _firebase.getAllOrders(),
        _firebase.getAllCategories(),
      ]);
      if (mounted) {
        setState(() {
          _productCount = (results[0] as List).length;
          _orderCount = (results[1] as List).length;
          _categoryCount = (results[2] as List).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// هيكل شيمر خفيف أثناء تحميل الإحصائيات
  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // عنوان القسم
        Container(
          width: 120, height: 20,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        // صف البطاقات الإحصائية
        Row(
          children: List.generate(3, (_) => const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
            ),
          )),
        ),
        const SizedBox(height: 32),
        // قائمة عناصر الإدارة
        ...List.generate(5, (_) => Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(14),
          ),
        )),
      ],
    );
  }

  // =================== مزامنة قواعد البيانات ===================

  /// مزامنة فئات المنتجات مع قاعدة البيانات في Firestore
  /// تكتب الفئات الـ 8 الجديدة وتُهاجر المنتجات القديمة
  Future<void> _syncCategoriesAndMigrate() async {
    setState(() => _syncing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final categoriesRef = FirebaseFirestore.instance.collection('categories');
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1️⃣ كتابة الفئات الجديدة
      for (int i = 0; i < AppConstants.categories.length; i++) {
        final cat = AppConstants.categories[i];
        final docRef = categoriesRef.doc(cat['id']);
        batch.set(docRef, {
          'id': cat['id'],
          'name': cat['name'],
          'nameEn': cat['nameEn'],
          'icon': cat['icon'],
          'order': i,
          'isActive': true,
          'productCount': 0,
          'createdAt': now,
        }, SetOptions(merge: true));
      }

      // 2️⃣ البحث عن المنتجات ذات الفئات القديمة
      final oldIdToNew = <String, String>{
        'thobes': 'shamzan',
        'suits': 'jackets',
        'shirts': 'fanail',
        'trousers': 'pajamas',
        'accessories': 'belts',
        'winter': 'jackets',
        'bisht': 'jackets',
        'shemagh': 'aqwat',
      };

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      int migratedCount = 0;
      final newCategoryIds = AppConstants.categories
          .map((c) => c['id'] as String)
          .toSet();

      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final oldCategoryId = productData['categoryId'] as String?;
        final oldCategoryName = productData['categoryName'] as String?;

        if (oldCategoryId != null && !newCategoryIds.contains(oldCategoryId)) {
          // 🐛 هجرة الفئة القديمة إلى الفئة الجديدة
          final newId = oldIdToNew[oldCategoryId] ?? 'other';

          // البحث عن الاسم العربي للفئة الجديدة
          String newName = oldCategoryName ?? '';
          for (final c in AppConstants.categories) {
            if (c['id'] == newId) {
              newName = c['name'] as String;
              break;
            }
          }

          batch.update(productDoc.reference, {
            'categoryId': newId,
            'categoryName': newName,
          });
          migratedCount++;
        }
      }

      // 3️⃣ تنفيذ الدفعة
      await batch.commit();

      if (!mounted) return;

      // إعادة تحميل الإحصائيات
      await _loadStats();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ تمت المزامنة بنجاح\n'
            '${AppConstants.categories.length} فئة منشأة\n'
            '$migratedCount منتج تم تحديث فئته',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشلت المزامنة: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0]
                        : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _loading
            ? _buildSkeleton()
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // إحصائيات سريعة
                    const Text(
                      'نظرة عامة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(
                          icon: Icons.inventory_2,
                          label: 'المنتجات',
                          value: '$_productCount',
                          color: AppColors.primary,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(
                          icon: Icons.receipt_long,
                          label: 'الطلبات',
                          value: '$_orderCount',
                          color: AppColors.success,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(
                          icon: Icons.category,
                          label: 'الفئات',
                          value: '$_categoryCount',
                          color: AppColors.warning,
                        )),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // قسم الإدارة
                    const Text(
                      'إدارة المتجر',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _AdminMenuItem(
                      icon: Icons.inventory_2,
                      title: 'المنتجات',
                      subtitle: 'إضافة، تعديل، حذف المنتجات',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuItem(
                      icon: Icons.category,
                      title: 'الفئات',
                      subtitle: 'إدارة فئات المنتجات',
                      color: AppColors.warning,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuItem(
                      icon: Icons.receipt_long,
                      title: 'الطلبات',
                      subtitle: 'عرض وإدارة الطلبات',
                      color: AppColors.success,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuItem(
                      icon: Icons.view_carousel,
                      title: 'البانرات',
                      subtitle: 'إدارة الإعلانات والبانرات الدوارة',
                      color: AppColors.info,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminBannersScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuItem(
                      icon: Icons.bolt,
                      title: 'التخفيضات الخاطفة',
                      subtitle: 'جدولة تخفيضات محدودة مع إشعارات فورية',
                      color: AppColors.error,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminFlashSaleScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuItem(
                      icon: Icons.people,
                      title: 'المستخدمين',
                      subtitle: 'إدارة صلاحيات المستخدمين',
                      color: AppColors.info,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // قسم الأدوات
                    const Text(
                      'أدوات الصيانة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // إدارة التبويبات
                    _AdminMenuItem(
                      icon: Icons.tab,
                      title: 'إدارة التبويبات',
                      subtitle: 'تشغيل/إيقاف التبويبات الظاهرة في الشريط السفلي',
                      color: AppColors.info,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TabManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // مزامنة الفئات
                    _AdminMenuItem(
                      icon: Icons.sync,
                      title: 'مزامنة بيانات الفئات',
                      subtitle: 'كتابة الفئات الجديدة في Firestone وترحيل المنتجات القديمة',
                      color: AppColors.success,
                      onTap: _syncing
                          ? null
                          : () => _syncCategoriesAndMigrate(),
                    ),
                    if (_syncing)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

/// بطاقة إحصائية
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// عنصر قائمة الإدارة
class _AdminMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final void Function()? onTap;

  const _AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
