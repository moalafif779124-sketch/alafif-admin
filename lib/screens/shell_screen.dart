import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../providers/auth_provider.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_products_screen.dart';
import 'admin/admin_orders_screen.dart';
import 'admin/admin_banners_screen.dart';
import 'admin/admin_flash_sale_screen.dart';
import 'admin/admin_analytics_screen.dart';

/// الهيكل الرئيسي لتطبيق الإدارة — تبويبات إدارة المتجر
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // ===== تبويبات كسولة (Lazy Tabs) =====
  // القائمة تنمو تدريجياً: التبويب يُنشأ عند أول زيارة له فقط.
  // IndexedStack يبني ويُجهّز كل أبنائه دفعة واحدة، وكل شاشة تجلب
  // بياناتها وتفكّك صورها فور إنشائها (منتجات، طلبات، بانرات base64،
  // تخفيضات، إحصائيات). كان فتح لوحة التحكم ينشئ الست شاشات معاً —
  // استهلاك ذاكرة عالٍ وفّر فرصة لسقوط التطبيق عند وصول كل البيانات
  // بنفس اللحظة. الآن تُنشأ الشاشة عند أول نقرة، وتُحفظ حالتها بعدها.
  final List<Widget> _tabCache = [];

  static Widget _createTab(int index) {
    return switch (index) {
      0 => const AdminDashboard(),
      1 => const AdminProductsScreen(),
      2 => const AdminOrdersScreen(),
      3 => const AdminBannersScreen(),
      4 => const AdminFlashSaleScreen(),
      _ => const AdminAnalyticsScreen(),
    };
  }

  /// يضمن وجود التبويب الحالي في القائمة (يُنشئ غير المزار سابقاً)
  void _ensureTab(int index) {
    while (_tabCache.length <= index) {
      _tabCache.add(_createTab(_tabCache.length));
    }
  }

  final List<IconData> _icons = const [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.receipt_long_outlined,
    Icons.view_carousel_outlined,
    Icons.bolt_outlined,
    Icons.analytics_outlined,
  ];

  final List<String> _labels = const [
    'لوحة التحكم',
    'المنتجات',
    'الطلبات',
    'البانرات',
    'التخفيضات',
    'الإحصائيات',
  ];

  void _logout() async {
    // بوابة الدخول في main.dart تراقب حالة المصادقة
    // وعند تسجيل الخروج تعيد توجيه المستخدم تلقائياً لشاشة الدخول
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    _ensureTab(_currentIndex);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabCache),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          destinations: List.generate(_labels.length, (i) {
            return NavigationDestination(
              icon: Icon(_icons[i]),
              selectedIcon: Icon(_icons[i], color: AppColors.primary),
              label: _labels[i],
            );
          }),
        ),
      ),
    );
  }
}
