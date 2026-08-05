import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // =========== الألوان ===========
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),

      // =========== الاتجاه (RTL) ===========
      // يتم ضبط RTL عبر MaterialApp نفسها

      // =========== الخطوط ===========
      fontFamily: 'NotoKufiArabic',

      // =========== شريط التطبيق ===========
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textOnPrimary,
        ),
      ),

      // =========== الأزرار ===========
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =========== حقول الإدخال ===========
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: AppColors.textSecondary,
        ),
      ),

      // =========== البطاقات ===========
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // =========== التبويبات ===========
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 12,
        ),
      ),

      // =========== علامات التبويب ===========
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 14,
        ),
      ),

      // =========== الشرائح ===========
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.accentLight,
        overlayColor: Color(0x290D1B3E),
      ),

      // =========== عام ===========
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // =========== الشيب ===========
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // =========== التمرير ===========
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.accent),
        trackColor: WidgetStateProperty.all(AppColors.accentLight),
      ),
    );
  }

  /// الثيم الداكن — مستوحى من الفخامة الليلية
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D1B3E),
        primary: const Color(0xFF1A3A6E),
        secondary: const Color(0xFFD4A843),
        surface: const Color(0xFF12122A),
        error: const Color(0xFFEF4444),
        brightness: Brightness.dark,
      ),

      // =========== شريط التطبيق ===========
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A1A),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // =========== الأزرار ===========
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A843),
          foregroundColor: const Color(0xFF0A0A1A),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD4A843),
          side: const BorderSide(color: Color(0xFFD4A843), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFD4A843),
          textStyle: const TextStyle(
            fontFamily: 'NotoKufiArabic',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =========== حقول الإدخال ===========
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E3E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4A843), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFF9E9EB8),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          color: Color(0xFF9E9EB8),
        ),
      ),

      // =========== البطاقات ===========
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A36),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A4A), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // =========== التبويبات ===========
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A0A1A),
        selectedItemColor: Color(0xFFD4A843),
        unselectedItemColor: Color(0xFF6B6B8D),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 12,
        ),
      ),

      // =========== علامات التبويب ===========
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFFD4A843),
        unselectedLabelColor: Color(0xFF6B6B8D),
        indicatorColor: Color(0xFFD4A843),
        labelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 14,
        ),
      ),

      // =========== الشرائح ===========
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFD4A843),
        thumbColor: Color(0xFFD4A843),
        inactiveTrackColor: Color(0xFF2A2A4A),
        overlayColor: Color(0x29D4A843),
      ),

      // =========== عام ===========
      scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      dividerColor: const Color(0xFF2A2A4A),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A4A),
        thickness: 1,
        space: 1,
      ),

      // =========== الشيب ===========
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E1E3E),
        selectedColor: const Color(0xFFD4A843),
        labelStyle: const TextStyle(
          fontFamily: 'NotoKufiArabic',
          fontSize: 13,
          color: Color(0xFFE0E0F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
      ),

      // =========== التمرير ===========
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFFD4A843)),
        trackColor: WidgetStateProperty.all(const Color(0xFF2A2A4A)),
      ),
    );
  }
}
