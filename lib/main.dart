import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/auth/login_screen.dart';
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
class _AdminGate extends StatelessWidget {
  const _AdminGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // لم يتم التهيئة بعد
    if (!authProvider.isLoggedIn && authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // غير مسجل — شاشة الدخول
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // مسجل — لوحة التحكم الرئيسية
    return const MainShell();
  }
}
