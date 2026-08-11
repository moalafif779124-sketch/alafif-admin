import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/colors.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_image.dart';

/// إدارة فيديوهات اكتشف — إضافة/تعديل/إزالة فيديو لكل منتج
class ReelsManagerScreen extends StatefulWidget {
  const ReelsManagerScreen({super.key});

  @override
  State<ReelsManagerScreen> createState() => _ReelsManagerScreenState();
}

class _ReelsManagerScreenState extends State<ReelsManagerScreen> {
  final FirebaseService _firebase = FirebaseService();
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _filter = 'all'; // all | withVideo | noVideo

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _firebase.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = all.where((p) => p['isActive'] != false).toList();
      _loading = false;
    });
  }

  String _videoOf(Map<String, dynamic> p) =>
      (p['videoUrl'] ?? '').toString().trim();

  bool _hasVideo(Map<String, dynamic> p) => _videoOf(p).isNotEmpty;

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'withVideo':
        return _products.where(_hasVideo).toList();
      case 'noVideo':
        return _products.where((p) => !_hasVideo(p)).toList();
      default:
        return _products;
    }
  }

  Future<void> _setVideo(Map<String, dynamic> product, String url) async {
    try {
      await _firebase.updateProduct(product['id'], {'videoUrl': url.trim()});
      if (!mounted) return;
      setState(() => product['videoUrl'] = url.trim());
      _snack('تم حفظ الفيديو ✓', AppColors.success);
    } catch (e) {
      debugPrint('⚠️ set video failed: $e');
      if (mounted) _snack('فشل حفظ الفيديو', AppColors.error);
    }
  }

  Future<void> _removeVideo(Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الفيديو؟'),
        content: Text('سيتم إزالة الفيديو من "${product['name']}" ولن يظهر في تبويب اكتشف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _setVideo(product, '');
    }
  }

  Future<void> _editVideo(Map<String, dynamic> product) async {
    final controller = TextEditingController(text: _videoOf(product));
    bool uploading = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              _hasVideo(product) ? 'تعديل الفيديو' : 'إضافة فيديو — ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 2,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط فيديو مباشر (MP4)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        setDialogState(() => uploading = true);
                        try {
                          final picked = await ImagePicker().pickVideo(
                            source: ImageSource.gallery,
                            maxDuration: const Duration(seconds: 60),
                          );
                          if (picked != null) {
                            final fileName =
                                'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
                            final url =
                                await _firebase.uploadVideo(picked.path, fileName);
                            controller.text = url;
                          }
                        } catch (e) {
                          debugPrint('⚠️ upload failed: $e');
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'تعذر رفع الفيديو — الصق رابط مباشر (MP4) بدلاً من ذلك'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => uploading = false);
                          }
                        }
                      },
                icon: uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_outlined, size: 18),
                label: Text(uploading ? 'جاري الرفع...' : 'اختيار فيديو ورفعه'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = controller.text.trim();
                Navigator.pop(ctx);
                _setVideo(product, url);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة فيديوهات اكتشف'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // فلاتر
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _filterChip('all', 'الكل (${_products.length})'),
                  const SizedBox(width: 8),
                  _filterChip('withVideo',
                      'بفيديو (${_products.where(_hasVideo).length})'),
                  const SizedBox(width: 8),
                  _filterChip('noVideo',
                      'بدون فيديو (${_products.where((p) => !_hasVideo(p)).length})'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.video_library_outlined,
                                  size: 56, color: AppColors.textSecondary),
                              const SizedBox(height: 10),
                              const Text('لا توجد منتجات هنا'),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('تحديث'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final has = _hasVideo(p);
                            final images =
                                (p['images'] as List<dynamic>?) ?? const [];
                            final img = images.isNotEmpty
                                ? images.first as String
                                : null;
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: has
                                      ? AppColors.success.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: img != null && img.isNotEmpty
                                      ? AppImage(
                                          imageUrl: img,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          color: AppColors.accentLight,
                                          child: const Icon(
                                              Icons.inventory_2_outlined,
                                              color: AppColors.textSecondary),
                                        ),
                                ),
                                title: Text(
                                  (p['name'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  has
                                      ? '🎬 يوجد فيديو'
                                      : 'لا يوجد فيديو',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: has
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontWeight:
                                        has ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: has ? 'تعديل الفيديو' : 'إضافة فيديو',
                                      icon: Icon(
                                        has
                                            ? Icons.edit
                                            : Icons.video_call_outlined,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: () => _editVideo(p),
                                    ),
                                    if (has)
                                      IconButton(
                                        tooltip: 'إزالة الفيديو',
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppColors.error),
                                        onPressed: () => _removeVideo(p),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
