import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/shell_screen.dart';

/// تطبيق إدارة متجر العفيف نيوفورم — تطبيق مستقل يتصل بنفس قاعدة Firebase
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ALAFIFAdminApp());
}

class ALAFIFAdminApp extends StatelessWidget {
  const ALAFIFAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        title: 'العفيف نيوفورم — إدارة',
        debugShowCheckedModeBanner: false,

        // =========== الثيم ===========
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,

        // =========== RTL ===========
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supportedLocales) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == locale?.languageCode) {
              return supported;
            }
          }
          return supportedLocales.first;
        },

        // =========== بوابة المدير ===========
        home: const _AdminGate(),
      ),
    );
  }
}

/// بوابة الدخول — يظهر شاشة الدخول إذا لم يكن المستخدم مسجلاً
/// يهيئ Firebase والمصادقة عند أول تشغيل (مثل شاشة Splash في تطبيق المتجر)
class _AdminGate extends StatefulWidget {
  const _AdminGate();

  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // تهيئة Firebase + استرجاع الجلسة المحفوظة + استرجاع جلسة OTP
    // (initialize() محمية داخلياً بـ isInitialized — آمنة للنداء المتكرر)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized && mounted) {
        _initialized = true;
        context.read<AuthProvider>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // قبل اكتمال التهيئة — شاشة انتظار
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // جلسة OTP معلّقة (المستخدم في منتصف التحقق) — نُظهر شاشة OTP
    if (!authProvider.isLoggedIn && authProvider.otpSent) {
      return const OtpScreen();
    }

    // غير مسجل — شاشة الدخول
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // مسجل — لوحة التحكم الرئيسية
    return const MainShell();
  }
}
