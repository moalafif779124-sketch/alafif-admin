import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../services/firebase_service.dart';

/// شاشة إدارة التخفيضات الخاطفة (Flash Sales)
class AdminFlashSaleScreen extends StatefulWidget {
  const AdminFlashSaleScreen({super.key});

  @override
  State<AdminFlashSaleScreen> createState() => _AdminFlashSaleScreenState();
}

class _AdminFlashSaleScreenState extends State<AdminFlashSaleScreen> {
  final FirebaseService _firebase = FirebaseService();

  List<Map<String, dynamic>> _flashSales = [];
  bool _isLoading = true;

  // ===== نموذج إنشاء تخفيض =====
  final _formKey = GlobalKey<FormState>();
  String? _productId;
  String? _productName;
  final _discountController = TextEditingController();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 24));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFlashSales();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadFlashSales() async {
    setState(() => _isLoading = true);
    final sales = await _firebase.getAllFlashSales();
    if (mounted) setState(() {
      _flashSales = sales;
      _isLoading = false;
    });
  }

  Future<void> _saveFlashSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المنتج'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!_endTime.isAfter(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('وقت النهاية يجب أن يكون بعد وقت البداية'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final discount = int.parse(_discountController.text.trim());
      await _firebase.createFlashSale({
        'productId': _productId,
        'productName': _productName,
        'discountPercentage': discount,
        'startTime': _startTime.millisecondsSinceEpoch,
        'endTime': _endTime.millisecondsSinceEpoch,
        'isActive': true,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ تم إنشاء التخفيض وإرسال إشعار للمستخدمين'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating),
        );
      }
      await _loadFlashSales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteFlashSale(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف التخفيض'),
          content: const Text('هل أنت متأكد من حذف هذا التخفيض الخاطف؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حذف', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await _firebase.deleteFlashSale(id);
      await _loadFlashSales();
    }
  }

  Future<void> _pickProduct(VoidCallback onPicked) async {
    final products = await _firebase.getAllProducts();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختيار المنتج'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                final name = p['name'] ?? 'منتج';
                final price = p['price'] ?? 0;
                return ListTile(
                  title: Text(name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$price ريال'),
                  onTap: () => Navigator.of(dialogContext).pop(p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _productId = selected['id'] ?? selected['productId'];
        _productName = selected['name'].toString();
      });
      onPicked();
    }
  }

  String _formatTime(int? ts) {
    if (ts == null) return '—';
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'اليوم ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التخفيضات الخاطفة'),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateDialog(),
          icon: const Icon(Icons.add),
          label: const Text('تخفيض جديد'),
          backgroundColor: AppColors.primary,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _flashSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('لا توجد تخفيضات خاطفة بعد'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showCreateDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('إنشاء أول تخفيض'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _flashSales.length,
                    itemBuilder: (context, index) {
                      final sale = _flashSales[index];
                      final discount = sale['discountPercentage'] ?? 0;
                      final name = sale['productName'] ?? 'منتج';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'من ${_formatTime(sale['startTime'])} إلى ${_formatTime(sale['endTime'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _deleteFlashSale(sale['id']),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    _productId = null;
    _productName = null;
    _discountController.clear();
    _startTime = DateTime.now();
    _endTime = DateTime.now().add(const Duration(hours: 24));

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنشاء تخفيض خاطف'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اختيار المنتج
                    InkWell(
                      onTap: () => _pickProduct(() {
                        dialogSetState(() {});
                      }),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'المنتج',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _productName ?? 'اختر منتجاً...',
                          style: TextStyle(
                            color: _productName == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // نسبة الخصم
                  TextFormField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الخصم %',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.percent),
                    ),
                    validator: (v) {
                      final val = int.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0 || val > 90) {
                        return 'أدخل نسبة بين 1 و 90';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // وقت البداية
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                    title: const Text('بداية التخفيض', style: TextStyle(fontSize: 13)),
                    subtitle: Text(_formatTime(_startTime.millisecondsSinceEpoch)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startTime,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_startTime),
                        );
                        if (time != null) {
                          setState(() {
                            _startTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  // وقت النهاية
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
                    title: const Text('نهاية التخفيض', style: TextStyle(fontSize: 13)),
                    subtitle: Text(_formatTime(_endTime.millisecondsSinceEpoch)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endTime,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_endTime),
                        );
                        if (time != null) {
                          setState(() {
                            _endTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم إرسال إشعار فوري لجميع المستخدمين عند الإنشاء',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveFlashSale,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.notifications_active, size: 18),
              label: const Text('حفظ وإشعار'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
