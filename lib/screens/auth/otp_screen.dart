import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../shell_screen.dart';

/// شاشة إدخال رمز التحقق (OTP) - عبر واتساب
/// تظهر حقل الاسم للمستخدم الجديد مباشرة
/// تعرض رمز OTP بشكل واضح على الشاشة (وليس فقط في SnackBar)
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _needsName = false;

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // عرض رمز OTP للمستخدم عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.otpCode == null) {
        // استرجاع من SharedPreferences إذا ضاع من الذاكرة
        await auth.restoreOtpSession();
      }
      if (auth.otpCode != null && mounted) {
        _showOtpSnackbar(auth.otpCode!);
      }
    });
  }

  void _showOtpSnackbar(String otp) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔐 رمز التحقق: $otp'),
        backgroundColor: const Color(0xFF25D366),
        duration: const Duration(seconds: 15),
        action: SnackBarAction(
          label: 'نسخ',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: otp));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ تم نسخ الرمز'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    // نمرر OTP + الاسم (إذا كان ظاهراً) دفعة واحدة
    bool success;
    if (_needsName && _nameController.text.trim().isNotEmpty) {
      success = await auth.confirmOtp(
        otp: _otpController.text.trim(),
        fullName: _nameController.text.trim(),
      );
    } else {
      success = await auth.confirmOtp(otp: _otpController.text.trim());
    }

    // الانتقال بعد نجاح التحقق
    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.read<AuthProvider>().cancelOtp();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppColors.accentLight,
                ),
                const SizedBox(height: 24),
                const Text(
                  'رمز التحقق',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل رمز التحقق المرسل عبر واتساب',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // =========== عرض رمز OTP على الشاشة ===========
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.otpCode == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF25D366).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_open,
                                  color: Color(0xFF25D366), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '🔐 رمزك: ${auth.otpCode}',
                                style: const TextStyle(
                                  color: Color(0xFF25D366),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: auth.otpCode!),
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ تم نسخ الرمز'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: const Icon(Icons.copy,
                                    color: Color(0xFF25D366), size: 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'انسخ الرمز من الأعلى أو من رسالة واتساب',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // =========== حقل OTP ===========
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 28,
                      letterSpacing: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.accentLight,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'أدخل رمز التحقق كاملاً';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // =========== حقل الاسم (للمستخدم الجديد) ===========
                // يظهر فقط إذا كان المستخدم جديداً ويحتاج اسم
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    // نراقب الخطأ: إذا ظهر خطأ "الاسم مطلوب"، نضبط _needsName
                    if (!_needsName &&
                        auth.error != null &&
                        auth.error!.contains('الاسم')) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _needsName = true);
                      });
                    }

                    if (!_needsName) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_add,
                                size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(
                              'مستخدم جديد! أدخل اسمك الكامل:',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'الاسم الثلاثي',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.accentLight,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: AppColors.accentLight,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          validator: (v) {
                            if (_needsName && (v == null || v.trim().isEmpty)) {
                              return 'الاسم مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // =========== زر التأكيد ===========
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'تأكيد',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),

                // =========== زر إعادة الإرسال ===========
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isLoading) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () async {
                        await auth.resendOtp();
                        if (mounted && auth.otpCode != null) {
                          _showOtpSnackbar(auth.otpCode!);
                        }
                      },
                      child: const Text(
                        'إعادة إرسال الرمز',
                        style: TextStyle(color: AppColors.accentLight),
                      ),
                    );
                  },
                ),

                // =========== عرض الخطأ ===========
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.error == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
