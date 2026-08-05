import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';

/// شاشة إدارة الفئات
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final FirebaseService _firebase = FirebaseService();

  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final categories = await _firebase.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;

    final idController = TextEditingController(text: existing?['id'] ?? '');
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final nameEnController = TextEditingController(text: existing?['nameEn'] ?? '');
    final iconController = TextEditingController(text: existing?['icon'] ?? '');
    final imageUrlController = TextEditingController(text: existing?['imageUrl'] ?? '');
    final orderController = TextEditingController(
      text: (existing?['order'] ?? 0).toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isEdit ? 'تعديل الفئة' : 'إضافة فئة جديدة'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'المعرف (id) *',
                      hintText: 'معرف فريد للفئة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'الحقل مطلوب';
                      if (v.contains(' ')) return 'لا يسمح بمسافات';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم (عربي) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.text_fields),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameEnController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم (إنجليزي)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'الأيقونة',
                      hintText: 'مثال: thobe, suit, shirt',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emoji_symbols),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الصورة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: orderController,
                    decoration: const InputDecoration(
                      labelText: 'الترتيب',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sort),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'nameEn': nameEnController.text.trim(),
                  'icon': iconController.text.trim(),
                  'imageUrl': imageUrlController.text.trim(),
                  'order': int.tryParse(orderController.text.trim()) ?? 0,
                  'isActive': true,
                };

                try {
                  if (isEdit) {
                    await _firebase.updateCategory(existing['id'], data);
                  } else {
                    data['id'] = idController.text.trim();
                    await _firebase.addCategory(data);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('فشل الحفظ: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'تحديث' : 'إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      _loadCategories();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف الفئة "${category['name']}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تراجع'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firebase.deleteCategory(category['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الفئة بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadCategories();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حذف الفئة: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الفئات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCategoryDialog(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 80,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد فئات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showCategoryDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة فئة جديدة'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCategories,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _buildCategoryCard(category);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final isActive = category['isActive'] as bool? ?? true;
    final name = category['name'] as String? ?? '';
    final nameEn = category['nameEn'] as String? ?? '';
    final icon = category['icon'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showCategoryDialog(existing: category),
        onLongPress: () => _confirmDelete(category),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.category,
            color: AppColors.warning,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nameEn.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                nameEn,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (icon.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'الأيقونة: $icon',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'نشط' : 'غير نشط',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
