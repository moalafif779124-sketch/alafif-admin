import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/colors.dart';
import '../../services/firebase_service.dart';

/// إدارة أكواد الخصم (`coupons/{CODE}`).
///
/// الكود نفسه هو معرّف المستند (أحرف كبيرة)، وتطبّقه شاشة الدفع في تطبيق
/// العميل بعد التحقق من: التفعيل، الصلاحية، أقل مجموع، وعدد الاستخدامات.
/// المستخدم يقرأ كوداً بالاسم فقط ولا يستطيع سرد الأكواد (قاعدة list: admin).
class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  final FirebaseService _firebase = FirebaseService();
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firebase.getCoupons();
    if (!mounted) return;
    setState(() {
      _coupons = list;
      _loading = false;
    });
  }

  String _valueLabel(Map<String, dynamic> c) {
    final type = (c['type'] ?? 'percent') as String;
    final value = (c['value'] as num?)?.toDouble() ?? 0;
    return type == 'fixed'
        ? '${value.toStringAsFixed(0)} ريال'
        : '${value.toStringAsFixed(0)}٪';
  }

  Future<void> _toggle(Map<String, dynamic> c, bool active) async {
    try {
      await _firebase.setCouponActive(c['code'] as String, active);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر التحديث: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الكود'),
        content: Text('حذف الكود ${c['code']} نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _firebase.deleteCoupon(c['code'] as String);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أكواد الخصم'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCouponDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text('كود جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _coupons.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.local_offer_outlined,
                            size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text('لا توجد أكواد خصم بعد — أضف أول كود'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemCount: _coupons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _coupons[i];
                        final used = (c['usedCount'] as num?)?.toInt() ?? 0;
                        final maxUses = (c['maxUses'] as num?)?.toInt() ?? 0;
                        final minSubtotal = (c['minSubtotal'] as num?)?.toDouble() ?? 0;
                        final active = c['active'] == true;
                        final expires = c['expiresAt'];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        c['code'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'خصم ${_valueLabel(c)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: active,
                                      onChanged: (v) => _toggle(c, v),
                                      activeColor: AppColors.success,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (minSubtotal > 0)
                                      'أقل مجموع ${minSubtotal.toStringAsFixed(0)} ريال',
                                    maxUses > 0
                                        ? 'استُخدم $used من $maxUses'
                                        : 'استُخدم $used (بلا حد)',
                                    if (expires is Timestamp)
                                      'ينتهي ${_date(expires.toDate())}',
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showCouponDialog(existing: c),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('تعديل'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _delete(c),
                                      icon: Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.error),
                                      label: Text('حذف',
                                          style: TextStyle(color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _showCouponDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final codeC = TextEditingController(text: existing?['code'] ?? '');
    final valueC = TextEditingController(
        text: (existing?['value'] as num?)?.toString() ?? '');
    final minC = TextEditingController(
        text: (existing?['minSubtotal'] as num?)?.toString() ?? '0');
    final maxUsesC = TextEditingController(
        text: (existing?['maxUses'] as num?)?.toString() ?? '0');
    String type = (existing?['type'] as String?) ?? 'percent';
    bool active = existing?['active'] == true;
    DateTime? expiry = (existing?['expiresAt'] is Timestamp)
        ? (existing!['expiresAt'] as Timestamp).toDate()
        : null;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isEdit ? 'تعديل كود الخصم' : 'كود خصم جديد'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeC,
                      enabled: !isEdit,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'الكود',
                        hintText: 'ALAFIF10',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                      ],
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 3) return '٣ أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'نوع الخصم',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية ٪')),
                        DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ريال)')),
                      ],
                      onChanged: (v) => setDialogState(() => type = v ?? 'percent'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: valueC,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: type == 'percent' ? 'النسبة (١–٥٠)' : 'المبلغ بالريال',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final d = double.tryParse((v ?? '').trim());
                        if (d == null || d <= 0) return 'قيمة غير صحيحة';
                        if (type == 'percent' && d > 50) return 'الحد الأقصى ٥٠٪';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: minC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'أقل مجموع فرعي (٠ = بلا حد)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: maxUsesC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'أقصى عدد استخدامات (٠ = بلا حد)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expiry == null
                                ? 'بلا تاريخ انتهاء'
                                : 'ينتهي: ${_date(expiry!)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: expiry ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setDialogState(() => expiry = picked);
                            }
                          },
                          child: const Text('تحديد'),
                        ),
                        if (expiry != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setDialogState(() => expiry = null),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('مفعّل'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                      activeColor: AppColors.success,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final code = codeC.text.trim().toUpperCase();
                        setDialogState(() => saving = true);
                        try {
                          final data = <String, dynamic>{
                            'code': code,
                            'type': type,
                            'value': double.parse(valueC.text.trim()),
                            'minSubtotal': double.tryParse(minC.text.trim()) ?? 0,
                            'maxUses': int.tryParse(maxUsesC.text.trim()) ?? 0,
                            'active': active,
                            if (!isEdit) 'usedCount': 0,
                            'updatedAt': DateTime.now().millisecondsSinceEpoch,
                            if (expiry != null)
                              'expiresAt': Timestamp.fromDate(DateTime(
                                  expiry!.year, expiry!.month, expiry!.day, 23, 59, 59))
                            else
                              'expiresAt': FieldValue.delete(),
                          };
                          await _firebase.saveCoupon(code, data);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('فشل الحفظ: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final c in [codeC, valueC, minC, maxUsesC]) {
      c.dispose();
    }
    if (saved == true) await _load();
  }
}
