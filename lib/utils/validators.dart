import 'package:flutter/material.dart';

/// دوال التحقق من صحة المدخلات
class Validators {
  /// التحقق من رقم الجوال
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الجوال';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 7 || cleaned.length > 15) {
      return 'رقم جوال غير صحيح';
    }
    return null;
  }

  /// التحقق من الاسم
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال الاسم';
    }
    if (value.trim().length < 3) {
      return 'الاسم قصير جداً';
    }
    if (value.trim().length > 100) {
      return 'الاسم طويل جداً';
    }
    return null;
  }

  /// التحقق من كلمة المرور
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (value.length > 50) {
      return 'كلمة المرور طويلة جداً';
    }
    return null;
  }

  /// التحقق من تأكيد كلمة المرور
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'يرجى تأكيد كلمة المرور';
    }
    if (value != password) {
      return 'كلمة المرور غير متطابقة';
    }
    return null;
  }

  /// التحقق من العنوان
  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال العنوان';
    }
    if (value.trim().length < 5) {
      return 'العنوان قصير جداً';
    }
    return null;
  }

  /// التحقق من نص عام
  static String? required(String? value, [String fieldName = 'هذا الحقل']) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى ملء $fieldName';
    }
    return null;
  }
}
