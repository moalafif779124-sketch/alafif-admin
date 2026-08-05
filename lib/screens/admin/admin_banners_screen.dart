import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../widgets/app_image.dart';

/// شاشة إدارة البانرات — مع رفع الصور من الجهاز (Image Picker)
class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final FirebaseService _firebase = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _loading = true);
    try {
      final banners = await _firebase.getBannersByOrder();
      if (mounted) {
        setState(() {
          _banners = banners;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// التقاط صورة من المعرض وضغطها إلى Base64 (JPEG مضغوط)
  Future<String?> _pickAndCompressImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      // تحويل إلى Base64 مع البادئة
      final b64 = base64Encode(bytes);
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,$b64';
    } catch (e) {
      debugPrint('⚠️ Image pick error: $e');
      return null;
    }
  }

  Future<void> _showBannerDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final subtitleC = TextEditingController(text: existing?['subtitle'] ?? '');
    final imageUrlC = TextEditingController(text: existing?['imageUrl'] ?? '');
    final buttonTextC = TextEditingController(text: existing?['buttonText'] ?? 'تسوق الآن');
    final orderC = TextEditingController(text: (existing?['order'] ?? _banners.length).toString());
    String? productId = existing?['productId'];
    String? categoryId = existing?['categoryId'];
    bool isActive = existing?['isActive'] ?? true;
    String? pendingImageB64;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isEdit ? 'تعديل البانر' : 'إضافة بانر جديد'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== معاينة الصورة مع زر الرفع =====
                    GestureDetector(
                      onTap: () async {
                        final b64 = await _pickAndCompressImage();
                        if (b64 != null) {
                          setDialogState(() {
                            pendingImageB64 = b64;
                            imageUrlC.text = b64;
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (pendingImageB64 ?? imageUrlC.text).isNotEmpty
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AppImage(
                                      imageUrl: pendingImageB64 ?? imageUrlC.text,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 120,
                                    ),
                                    Container(
                                      alignment: Alignment.bottomCenter,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('تغيير الصورة', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.textSecondary),
                                    const SizedBox(height: 4),
                                    const Text('اختيار صورة من الجهاز', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ===== حقل العنوان =====
                    TextFormField(
                      controller: titleC,
                      decoration: const InputDecoration(labelText: 'العنوان *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: subtitleC,
                      decoration: const InputDecoration(labelText: 'النص الفرعي', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subtitles)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: buttonTextC,
                      decoration: const InputDecoration(labelText: 'نص الزر', border: OutlineInputBorder(), prefixIcon: Icon(Icons.smart_button)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: orderC,
                            decoration: const InputDecoration(labelText: 'الترتيب', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sort)),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // زر التفعيل
                        Column(
                          children: [
                            const Text('نشط', style: TextStyle(fontSize: 11)),
                            Switch.adaptive(
                              value: isActive,
                              onChanged: (v) => setDialogState(() => isActive = v),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'معرف المنتج (للبانر المرتبط بمنتج)', hintText: 'prod_01', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
                      initialValue: productId ?? '',
                      onChanged: (v) => productId = v.isEmpty ? null : v,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'معرف الفئة (للبانر المرتبط بفئة)', hintText: 'mawaz', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      initialValue: categoryId ?? '',
                      onChanged: (v) => categoryId = v.isEmpty ? null : v,
                    ),
                    // حقل الرابط اليدوي (اختياري)
                    if (pendingImageB64 == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          controller: imageUrlC,
                          decoration: const InputDecoration(
                            labelText: 'أو رابط الصورة (اختياري)',
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  // استخدام الصورة المرفوعة أو الرابط اليدوي أو الصورة القديمة
                  final finalImage = pendingImageB64 ?? imageUrlC.text.trim();
                  if (finalImage.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('الرجاء اختيار صورة'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  final data = <String, dynamic>{
                    'title': titleC.text.trim(),
                    'subtitle': subtitleC.text.trim(),
                    'imageUrl': finalImage,
                    'buttonText': buttonTextC.text.trim(),
                    'order': int.tryParse(orderC.text.trim()) ?? _banners.length,
                    'isActive': isActive,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                  };
                  if (productId != null && productId!.isNotEmpty) data['productId'] = productId;
                  if (categoryId != null && categoryId!.isNotEmpty) data['categoryId'] = categoryId;

                  try {
                    if (isEdit) {
                      await _firebase.updateBanner(existing['id'], data);
                    } else {
                      await _firebase.addBanner(data);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(isEdit ? 'تحديث' : 'إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && mounted) _loadBanners();
  }

  Future<void> _toggleBanner(Map<String, dynamic> banner) async {
    try {
      await _firebase.updateBanner(banner['id'], {'isActive': !(banner['isActive'] ?? true)});
      _loadBanners();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحديث: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف البانر'),
          content: Text('هل تريد حذف "${banner['title'] ?? ''}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _firebase.deleteBanner(banner['id']);
        _loadBanners();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحذف'), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// إضافة بانرات افتراضية إلى Firestore كبداية سريعة
  Future<void> _seedDefaultBanners() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      {'title': 'المجموعة الشتوية 2026', 'subtitle': 'تصاميم عصرية بأقمشة فاخرة', 'imageUrl': '', 'buttonText': 'تسوق الآن', 'order': 0, 'isActive': true, 'createdAt': now},
      {'title': 'خصومات تصل إلى 50%', 'subtitle': 'على تشكيلة الثياب والبذلات', 'imageUrl': '', 'buttonText': 'استفد من العرض', 'order': 1, 'isActive': true, 'createdAt': now},
      {'title': 'أزياء العيد', 'subtitle': 'أفخم التصاميم للمناسبات السعيدة', 'imageUrl': '', 'buttonText': 'اكتشف المجموعة', 'order': 2, 'isActive': true, 'createdAt': now},
    ];
    try {
      for (final banner in defaults) {
        await _firebase.addBanner(banner);
      }
      await _loadBanners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تمت إضافة 3 بانرات افتراضية'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإضافة: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة البانرات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showBannerDialog(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _banners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_carousel_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('لا توجد بانرات', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showBannerDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة بانر جديد'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _seedDefaultBanners(),
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('إضافة بانرات افتراضية'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBanners,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _banners.length,
                      itemBuilder: (context, index) => _buildBannerCard(_banners[index], index),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner, int index) {
    final isActive = banner['isActive'] as bool? ?? true;
    final title = banner['title'] as String? ?? '';
    final subtitle = banner['subtitle'] as String? ?? '';
    final order = banner['order'] ?? index;
    final imageUrl = banner['imageUrl'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // رقم الترتيب
            Container(
              width: 36, height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${order + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            // صورة مصغرة
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(imageUrl: imageUrl, width: 48, height: 48, fit: BoxFit.cover, cacheWidth: 96),
                ),
              ),
            // تفاصيل البانر
            Expanded(
              child: GestureDetector(
                onTap: () => _showBannerDialog(existing: banner),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: GestureDetector(
                            onTap: () => _toggleBanner(banner),
                            child: Text(
                              isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.error),
                            ),
                          ),
                        ),
                        if (banner['productId'] != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.link, size: 12, color: AppColors.info),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // زر الحذف
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withValues(alpha: 0.7)),
              onPressed: () => _deleteBanner(banner),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}
