import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/navigation_provider.dart';

/// شاشة إدارة التبويبات — تشغيل/إيقاف، تعديل التسميات
class TabManagementScreen extends StatefulWidget {
  const TabManagementScreen({super.key});

  @override
  State<TabManagementScreen> createState() => _TabManagementScreenState();
}

class _TabManagementScreenState extends State<TabManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة التبويبات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'إعادة تعيين',
              onPressed: _confirmReset,
            ),
          ],
        ),
        body: Consumer<NavigationProvider>(
          builder: (context, nav, _) {
            if (nav.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (nav.allTabs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tab_unselected, size: 80,
                        color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text('لا توجد تبويبات', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => nav.resetToDefaults(),
                      child: const Text('استعادة الافتراضي'),
                    ),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'تحكم في التبويبات الظاهرة في الشريط السفلي. '
                          'التغييرات تنعكس فوراً على جميع المستخدمين.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // قائمة التبويبات
                ...nav.allTabs.map((tab) => _buildTabTile(nav, tab)),
                const SizedBox(height: 16),
                // ملخص
                Text(
                  'ظاهر: ${nav.tabs.length} من ${nav.allTabs.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabTile(NavigationProvider nav, TabConfig tab) {
    final iconMap = <String, IconData>{
      'home': Icons.home,
      'category': Icons.grid_view,
      'live': Icons.live_tv,
      'cart': Icons.shopping_cart,
      'profile': Icons.person,
    };
    final icon = iconMap[tab.id] ?? Icons.tab;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tab.isActive
              ? AppColors.border
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // أيقونة
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: (tab.isActive ? AppColors.primary : AppColors.textSecondary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tab.isActive ? AppColors.primary : AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            // الاسم وقابلية التعديل
            Expanded(
              child: GestureDetector(
                onTap: () => _editLabel(nav, tab),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.labelAr.isNotEmpty ? tab.labelAr : _defaultLabel(tab.id),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: tab.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tab.id} · ترتيب ${tab.order + 1}',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // زر التفعيل
            Switch.adaptive(
              value: tab.isActive,
              onChanged: (_) => nav.toggleTab(tab.id),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLabel(NavigationProvider nav, TabConfig tab) async {
    final controller = TextEditingController(text: tab.labelAr);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل التسمية'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'التسمية العربية',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await nav.updateLabel(tab.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث تسمية "${result}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعادة تعيين'),
          content: const Text('هل تريد إعادة جميع التبويبات إلى الإعدادات الافتراضية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      context.read<NavigationProvider>().resetToDefaults();
    }
  }

  String _defaultLabel(String id) {
    const labels = {
      'home': 'الرئيسية',
      'category': 'الفئات',
      'live': 'المجتمع',
      'cart': 'السلة',
      'profile': 'حسابي',
    };
    return labels[id] ?? id;
  }
}
