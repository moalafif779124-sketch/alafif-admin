import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../providers/auth_provider.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_products_screen.dart';
import 'admin/admin_orders_screen.dart';
import 'admin/admin_banners_screen.dart';
import 'admin/admin_flash_sale_screen.dart';

/// الهيكل الرئيسي لتطبيق الإدارة — تبويبات إدارة المتجر
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    AdminDashboard(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    AdminBannersScreen(),
    AdminFlashSaleScreen(),
  ];

  final List<IconData> _icons = const [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.receipt_long_outlined,
    Icons.view_carousel_outlined,
    Icons.bolt_outlined,
  ];

  final List<String> _labels = const [
    'لوحة التحكم',
    'المنتجات',
    'الطلبات',
    'البانرات',
    'التخفيضات',
  ];

  void _logout() async {
    // بوابة الدخول في main.dart تراقب حالة المصادقة
    // وعند تسجيل الخروج تعيد توجيه المستخدم تلقائياً لشاشة الدخول
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabs),
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
