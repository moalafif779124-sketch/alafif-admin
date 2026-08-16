import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../widgets/app_image.dart';

/// شاشة إضافة/تعديل منتج
class AdminProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProduct;

  const AdminProductFormScreen({super.key, this.existingProduct});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final FirebaseService _firebase = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _oldPriceController;
  late TextEditingController _discountPercentageController;
  late TextEditingController _imagesController;
  late TextEditingController _brandController;
  late TextEditingController _materialController;
  late TextEditingController _careInstructionsController;
  late TextEditingController _tagsController;

  // ===== الحقول الجديدة =====
  late TextEditingController _stockQuantityController;
  late TextEditingController _sizeRangeController;
  late TextEditingController _videoUrlController;
  List<String> _selectedColors = [];
  bool _isRangeSize = false;
  bool _uploadingVideo = false;
  // =========================

  // ===== تنسيق الإطلالة (اختياري) =====
  List<String> _linkedOutfitIds = [];
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = false;

  String? _categoryId;
  List<String> _selectedSizes = [];
  final Map<String, TextEditingController> _stockVariantControllers = {};
  bool _isFeatured = false;
  bool _isNewArrival = false;
  bool _hasDiscount = false;

  /// خيارات العرض الإضافية (خريطة أعلام)
  final Map<String, bool> _displayOptions = {
    'eid': false,
    'winter': false,
    'new': false,
    'offers': false,
    'limited': false,
  };

  // الصور
  final List<String> _imageUrls = [];
  bool _uploadingImage = false;

  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  bool _saving = false;

  bool get _isEditMode => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _oldPriceController = TextEditingController();
    _discountPercentageController = TextEditingController();
    _imagesController = TextEditingController();
    _brandController = TextEditingController(text: 'ALAFIF NEWFORM');
    _materialController = TextEditingController();
    _careInstructionsController = TextEditingController();
    _tagsController = TextEditingController();
    _stockQuantityController = TextEditingController();
    _sizeRangeController = TextEditingController();
    _videoUrlController = TextEditingController();

    _loadCategories();
    _loadAllProducts();

    if (_isEditMode) {
      _populateForm();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _discountPercentageController.dispose();
    _imagesController.dispose();
    _brandController.dispose();
    _materialController.dispose();
    _careInstructionsController.dispose();
    _tagsController.dispose();
    _stockQuantityController.dispose();
    _sizeRangeController.dispose();
    _videoUrlController.dispose();
    for (final c in _stockVariantControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _firebase.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  /// جلب كل المنتجات النشطة لعرضها في منتقي تنسيق الإطلالة
  Future<void> _loadAllProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final result = await _firebase.getProducts(limit: 500);
      if (mounted) {
        setState(() {
          _allProducts = List<Map<String, dynamic>>.from(
            result['products'] ?? [],
          );
          _loadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  /// منتقي الإطلالة — نافذة بحث واختيار حتى 3 منتجات مكملة
  Future<void> _pickOutfitProducts() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OutfitPickerSheet(
        products: _allProducts
            .where((p) => p['id'] != widget.existingProduct?['id'])
            .toList(),
        initialSelected: _linkedOutfitIds,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _linkedOutfitIds = selected);
    }
  }

  void _populateForm() {
    final p = widget.existingProduct!;
    _nameController.text = p['name'] ?? '';
    _descriptionController.text = p['description'] ?? '';
    _priceController.text = (p['price'] ?? 0).toString();
    _oldPriceController.text = p['oldPrice']?.toString() ?? '';
    _categoryId = p['categoryId'];
    _selectedSizes = List<String>.from(p['sizes'] ?? []);
    _imageUrls.clear();
    _imageUrls.addAll(List<String>.from(p['images'] ?? []));
    _isFeatured = p['isFeatured'] ?? false;
    _isNewArrival = p['isNewArrival'] ?? false;
    _hasDiscount = p['hasDiscount'] ?? false;
    _displayOptions.addAll(
      Map<String, bool>.from(p['displayOptions'] ?? const {}),
    );
    _discountPercentageController.text = (p['discountPercentage'] ?? 0).toString();
    _brandController.text = p['brand'] ?? 'ALAFIF NEWFORM';
    _materialController.text = p['material'] ?? '';
    _careInstructionsController.text = p['careInstructions'] ?? '';
    _tagsController.text = (p['tags'] as List<dynamic>?)?.join(', ') ?? '';
    _stockQuantityController.text = (p['stockQuantity'] ?? 0).toString();
    _sizeRangeController.text = p['sizeRange'] ?? '';
    _videoUrlController.text = p['videoUrl'] ?? '';
    // المخزون حسب المقاس
    _stockVariantControllers.clear();
    final savedVariants = (p['stockVariants'] as Map<String, dynamic>?) ?? {};
    savedVariants.forEach((size, qty) {
      _stockVariantControllers[size] =
          TextEditingController(text: qty.toString());
    });
    _selectedColors = (p['colorOptions'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>)['hex'] as String? ?? '')
            .where((h) => h.isNotEmpty)
            .toList() ??
        List<String>.from(p['colors'] ?? []);
    _isRangeSize = (p['sizeRange'] ?? '').isNotEmpty;
    _linkedOutfitIds = List<String>.from(p['linkedOutfitIds'] ?? []);
  }

  /// اختيار فيديو من المعرض ومحاولة رفعه إلى Firebase Storage
  /// عند فشل الرفع (مثل عدم تفعيل Storage) يُطلب رابط مباشر بدلاً من ذلك
  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked == null) return;
      setState(() => _uploadingVideo = true);

      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final url = await _firebase.uploadVideo(picked.path, fileName);

      if (!mounted) return;
      setState(() {
        _videoUrlController.text = url;
        _uploadingVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الفيديو بنجاح ✓'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Video upload failed: $e');
      if (!mounted) return;
      setState(() => _uploadingVideo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر رفع الفيديو — الصق رابط فيديو مباشر (MP4) بدلاً من ذلك'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null || _categoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الفئة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final imageList = List<String>.from(_imageUrls);

    final tagList = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final selectedCategory = _categories.firstWhere(
      (c) => c['id'] == _categoryId,
      orElse: () => {},
    );

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0,
      'oldPrice': double.tryParse(_oldPriceController.text.trim()),
      'categoryId': _categoryId,
      'categoryName': selectedCategory['name'] ?? '',
      'sizes': _selectedSizes,
      'sizeRange': _isRangeSize ? _sizeRangeController.text.trim() : '',
      'images': imageList,
      'colors': _selectedColors,
      'colorOptions': _selectedColors.map((hex) {
        final match = AppConstants.colorOptions.cast<Map<String, dynamic>>().firstWhere(
          (o) => o['hex'] == hex,
          orElse: () => {'name': hex, 'hex': hex},
        );
        return {'name': match['name'], 'hex': hex};
      }).toList(),
      'stock': {},
      'stockVariants': {
        for (final size in _selectedSizes)
          size: int.tryParse(
                  _stockVariantControllers[size]?.text.trim() ?? '') ??
              0,
      },
      'stockQuantity': int.tryParse(_stockQuantityController.text.trim()) ?? 0,
      'isFeatured': _isFeatured,
      'isNewArrival': _isNewArrival,
      'hasDiscount': _hasDiscount,
      'displayOptions': _displayOptions,
      'discountPercentage': int.tryParse(_discountPercentageController.text.trim()) ?? 0,
      'brand': _brandController.text.trim(),
      'material': _materialController.text.trim(),
      'careInstructions': _careInstructionsController.text.trim(),
      'videoUrl': _videoUrlController.text.trim(),
      'linkedOutfitIds': _linkedOutfitIds,
      'tags': tagList,
      'rating': 0,
      'reviewCount': 0,
    };

    try {
      if (_isEditMode) {
        await _firebase.updateProduct(widget.existingProduct!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث المنتج بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        data['isActive'] = true;
        await _firebase.addProduct(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة المنتج بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =================== اختيار ورفع الصور ===================

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _uploadingImage = true);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final downloadUrl = await _firebase.uploadImage(pickedFile.path, fileName);

      setState(() {
        _imageUrls.add(downloadUrl);
        _uploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم رفع الصورة بنجاح'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل رفع الصورة: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
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
          title: Text(_isEditMode ? 'تعديل المنتج' : 'إضافة منتج جديد'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // اسم المنتج
              _buildSectionTitle('معلومات المنتج الأساسية'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('اسم المنتج *', Icons.shopping_bag),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // الوصف
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('وصف المنتج', Icons.description),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // السعر
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: _inputDecoration('السعر *', Icons.attach_money),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'الحقل مطلوب';
                        if (double.tryParse(v.trim()) == null) return 'رقم غير صالح';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _oldPriceController,
                      decoration: _inputDecoration('السعر القديم', Icons.money_off),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // الخصم
              SwitchListTile(
                title: const Text('يوجد خصم'),
                value: _hasDiscount,
                onChanged: (v) => setState(() => _hasDiscount = v),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasDiscount)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _discountPercentageController,
                    decoration: _inputDecoration('نسبة الخصم (%)', Icons.percent),
                    keyboardType: TextInputType.number,
                  ),
                ),

              // فئة المنتج
              _buildSectionTitle('الفئة والمقاسات'),
              const SizedBox(height: 12),
              _loadingCategories
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: _inputDecoration('الفئة *', Icons.category),
                      items: _categories.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'],
                          child: Text(c['name'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'يرجى اختيار الفئة' : null,
                    ),
              const SizedBox(height: 16),

              // المخزون
              _buildSectionTitle('المخزون'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockQuantityController,
                decoration: _inputDecoration('كمية المخزون', Icons.inventory_2).copyWith(
                  helperText: 'العدد الإجمالي المتاح من هذا المنتج',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // المقاسات
              _buildSectionTitle('المقاسات'),
              const SizedBox(height: 12),
              // اختيار نوع المقاس (نطاق / قياسي)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('نطاق (1-60)'),
                      selected: _isRangeSize,
                      onSelected: (v) => setState(() => _isRangeSize = true),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _isRangeSize ? Colors.white : AppColors.textPrimary,
                        fontWeight: _isRangeSize ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('مقاسات قياسية'),
                      selected: !_isRangeSize,
                      onSelected: (v) => setState(() => _isRangeSize = false),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: !_isRangeSize ? Colors.white : AppColors.textPrimary,
                        fontWeight: !_isRangeSize ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isRangeSize)
                // إدخال نطاق المقاس
                TextFormField(
                  controller: _sizeRangeController,
                  decoration: _inputDecoration('نطاق المقاس', Icons.straighten).copyWith(
                    helperText: AppConstants.sizeRangeHint,
                  ),
                  keyboardType: TextInputType.text,
                )
              else
                // اختيار مقاسات قياسية (رقمية + أبجدية)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مقاسات رقمية', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.sizesNumeric.map((size) {
                        final selected = _selectedSizes.contains(size);
                        return FilterChip(
                          label: Text(size, style: const TextStyle(fontSize: 13)),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) { _selectedSizes.add(size); }
                              else { _selectedSizes.remove(size); }
                            });
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('مقاسات أبجدية', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.sizesStandard.map((size) {
                        final selected = _selectedSizes.contains(size);
                        return FilterChip(
                          label: Text(size, style: const TextStyle(fontSize: 13)),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) { _selectedSizes.add(size); }
                              else { _selectedSizes.remove(size); }
                            });
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // ===== المخزون حسب المقاس =====
                    if (_selectedSizes.isNotEmpty) ...[
                      const Text(
                        'المخزون حسب المقاس',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      ..._selectedSizes.map((size) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  size,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller:
                                      _stockVariantControllers.putIfAbsent(
                                    size,
                                    () => TextEditingController(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'الكمية (0 = نفذت الكمية)',
                                    Icons.inventory_2_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Text(
                        'أدخل 0 للمقاسات النافذة — سيظهر للمشتري "نفذت الكمية"',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 20),

              // الألوان
              _buildSectionTitle('الألوان'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppConstants.colorOptions.map((colorOption) {
                  final hex = colorOption['hex'] as String;
                  final name = colorOption['name'] as String;
                  final selected = _selectedColors.contains(hex);

                  Color parsedColor;
                  try {
                    parsedColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  } catch (_) {
                    parsedColor = const Color(0xFF808080);
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedColors.remove(hex);
                        } else {
                          _selectedColors.add(hex);
                        }
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: parsedColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppColors.primary : Colors.grey[300]!,
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // الصور
              _buildSectionTitle('الصور'),
              const SizedBox(height: 12),
              
              // الصور المرفوعة
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppImage(
                              imageUrl: _imageUrls[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _imageUrls.removeAt(index));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              
              // أزرار إضافة الصور
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploadingImage ? null : _pickAndUploadImage,
                      icon: _uploadingImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(_uploadingImage ? 'جاري الرفع...' : 'اختر من المعرض'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // أو إدخال رابط يدوي
              TextFormField(
                controller: _imagesController,
                decoration: _inputDecoration(
                  'أو أدخل رابط الصورة (اختياري)',
                  Icons.link,
                ).copyWith(
                  helperText: 'يمكنك إدخال رابط صورة بدلاً من الرفع',
                ),
                maxLines: 2,
                onFieldSubmitted: (value) {
                  final url = value.trim();
                  if (url.isNotEmpty && !_imageUrls.contains(url)) {
                    setState(() => _imageUrls.add(url));
                    _imagesController.clear();
                  }
                },
              ),
              const SizedBox(height: 16),

              // ===== فيديو المنتج (ريلز/اكتشف) =====
              _buildSectionTitle('فيديو المنتج (اكتشف)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoUrlController,
                decoration: _inputDecoration(
                  'رابط فيديو مباشر (MP4)',
                  Icons.videocam_outlined,
                ).copyWith(
                  helperText: 'الصق رابط فيديو مباشر MP4 — يظهر في تبويب "اكتشف"',
                ),
                maxLines: 2,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              if (_videoUrlController.text.trim().isNotEmpty) ...[
                _VideoPreview(
                  key: ValueKey(_videoUrlController.text),
                  url: _videoUrlController.text.trim(),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _uploadingVideo ? null : _pickVideo,
                icon: _uploadingVideo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library_outlined, size: 18),
                label: Text(
                    _uploadingVideo ? 'جاري الرفع...' : 'اختيار فيديو ورفعه'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),

              // خيارات إضافية
              _buildSectionTitle('خيارات العرض'),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('منتوج مميز'),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('وصل حديثاً'),
                value: _isNewArrival,
                onChanged: (v) => setState(() => _isNewArrival = v),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              _displayOptionTile(
                key: 'eid',
                title: 'ملابس العيد',
                icon: Icons.celebration_outlined,
              ),
              _displayOptionTile(
                key: 'winter',
                title: 'ملابس الشتاء',
                icon: Icons.ac_unit_outlined,
              ),
              _displayOptionTile(
                key: 'new',
                title: 'جديد العفيف نيوفورم',
                icon: Icons.fiber_new_outlined,
              ),
              _displayOptionTile(
                key: 'offers',
                title: 'عروض وتخفيضات',
                icon: Icons.local_offer_outlined,
              ),
              _displayOptionTile(
                key: 'limited',
                title: 'كمية محدودة',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 20),

              // معلومات إضافية
              _buildSectionTitle('معلومات إضافية'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: _inputDecoration('العلامة التجارية', Icons.branding_watermark),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _materialController,
                decoration: _inputDecoration('الخامة', Icons.texture),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _careInstructionsController,
                decoration: _inputDecoration('تعليمات العناية', Icons.local_laundry_service),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: _inputDecoration(
                  'الوسوم (مفصولة بفواصل)',
                  Icons.tag,
                ).copyWith(
                  helperText: 'مثال: ثوب, كلاسيك, قطني',
                ),
              ),
              const SizedBox(height: 24),

              // ===== تنسيق الإطلالة (اختياري) =====
              _buildSectionTitle('تنسيق الإطلالة (اختياري)'),
              const SizedBox(height: 4),
              Text(
                'اختر حتى 3 منتجات مكملة تظهر في قسم "صمم إطلالتك الكاملة" '
                'بشاشة المنتج — اتركها فارغة لإخفاء القسم',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
              // المنتجات المختارة
              if (_linkedOutfitIds.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _linkedOutfitIds.map((id) {
                    final prod = _allProducts
                        .where((p) => p['id'] == id)
                        .toList();
                    final name = prod.isNotEmpty
                        ? (prod.first['name'] as String? ?? 'منتج')
                        : 'منتج محذوف';
                    return InputChip(
                      label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(
                        () => _linkedOutfitIds.remove(id),
                      ),
                      backgroundColor: AppColors.accentLight,
                      deleteIconColor: AppColors.error,
                      side: const BorderSide(color: AppColors.primary, width: 0.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _loadingProducts ? null : _pickOutfitProducts,
                icon: _loadingProducts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.checkroom_outlined, size: 18),
                label: Text(
                  _linkedOutfitIds.isEmpty
                      ? 'اختيار منتجات الإطلالة'
                      : 'تعديل منتجات الإطلالة',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'تحديث المنتج' : 'إضافة المنتج',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  /// صف تبديل (Switch) لخيار عرض — يخزّن القيمة في _displayOptions
  Widget _displayOptionTile({
    required String key,
    required String title,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      value: _displayOptions[key] ?? false,
      onChanged: (v) => setState(() => _displayOptions[key] = v),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// معاينة فيديو المنتج (رابط مباشر MP4) — تشغيل صامت متكرر
class _VideoPreview extends StatefulWidget {
  final String url;

  const _VideoPreview({super.key, required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      c.setLooping(true);
      c.setVolume(0);
      await c.play();
      if (mounted) setState(() => _controller = c);
    } catch (e) {
      debugPrint('⚠️ Video preview failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'تعذر تحميل الفيديو — تحقق من الرابط',
            style: TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
      );
    }
    if (_controller == null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

/// ورقة منتقي منتجات الإطلالة — بحث + اختيار حتى 3 منتجات
class _OutfitPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final List<String> initialSelected;

  const _OutfitPickerSheet({
    required this.products,
    required this.initialSelected,
  });

  @override
  State<_OutfitPickerSheet> createState() => _OutfitPickerSheetState();
}

class _OutfitPickerSheetState extends State<_OutfitPickerSheet> {
  static const int _maxPick = 3;
  late final List<String> _selected;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where((p) =>
            (p['name'] as String? ?? '').toLowerCase().contains(q) ||
            (p['categoryName'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < _maxPick) {
        _selected.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يمكن اختيار ${_maxPick} منتجات كحد أقصى'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مقبض + عنوان
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تنسيق الإطلالة ✨',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'اختر حتى 3 منتجات مكملة تظهر في قسم "صمم إطلالتك الكاملة"',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // حقل البحث
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المنتج أو الفئة...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // عداد الاختيار
              Row(
                children: [
                  Text(
                    'المحدد: ${_selected.length} / $_maxPick',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            setState(_selected.clear);
                          },
                    child: const Text(
                      'مسح الكل',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // القائمة
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد منتجات مطابقة',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final id = p['id'] as String? ?? '';
                          final isSelected = _selected.contains(id);
                          final images = (p['images'] as List<dynamic>?) ?? [];
                          final name = p['name'] as String? ?? '';
                          final cat = p['categoryName'] as String? ?? '';
                          final price =
                              (p['price'] as num?)?.toDouble() ?? 0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppImage(
                                imageUrl: images.isNotEmpty
                                    ? images.first as String
                                    : '',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                backgroundColor: AppColors.accentLight,
                              ),
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$cat — ${price.toStringAsFixed(0)} ر.س',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.accent,
                              size: 22,
                            ),
                            onTap: () => _toggle(id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),

              // زر التأكيد
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  'تأكيد (${_selected.length})',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
