import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firebase_service.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
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
  List<String> _selectedColors = [];
  bool _isRangeSize = false;
  // =========================

  String? _categoryId;
  List<String> _selectedSizes = [];
  bool _isFeatured = false;
  bool _isNewArrival = false;
  bool _hasDiscount = false;

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

    _loadCategories();

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
    _discountPercentageController.text = (p['discountPercentage'] ?? 0).toString();
    _brandController.text = p['brand'] ?? 'ALAFIF NEWFORM';
    _materialController.text = p['material'] ?? '';
    _careInstructionsController.text = p['careInstructions'] ?? '';
    _tagsController.text = (p['tags'] as List<dynamic>?)?.join(', ') ?? '';
    _stockQuantityController.text = (p['stockQuantity'] ?? 0).toString();
    _sizeRangeController.text = p['sizeRange'] ?? '';
    _selectedColors = (p['colorOptions'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>)['hex'] as String? ?? '')
            .where((h) => h.isNotEmpty)
            .toList() ??
        List<String>.from(p['colors'] ?? []);
    _isRangeSize = (p['sizeRange'] ?? '').isNotEmpty;
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
      'stockQuantity': int.tryParse(_stockQuantityController.text.trim()) ?? 0,
      'isFeatured': _isFeatured,
      'isNewArrival': _isNewArrival,
      'hasDiscount': _hasDiscount,
      'discountPercentage': int.tryParse(_discountPercentageController.text.trim()) ?? 0,
      'brand': _brandController.text.trim(),
      'material': _materialController.text.trim(),
      'careInstructions': _careInstructionsController.text.trim(),
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
