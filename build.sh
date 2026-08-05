#!/bin/bash
# ============================================
# Build Script - ALAFIF NEWFORM Android App
# ============================================
# Usage: bash build.sh
# Requirements: Flutter SDK, Android SDK, Java 17

set -e

echo "╔══════════════════════════════════════════╗"
echo "║     بناء تطبيق ألافيف نيوفورم            ║"
echo "║     ALAFIF NEWFORM App Builder           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# التحقق من المتطلبات
echo "▸ التحقق من المتطلبات..."

if ! command -v flutter &> /dev/null; then
    echo "✗ Flutter غير مثبت. يرجى تثبيت Flutter SDK"
    echo "  https://flutter.dev/docs/get-started/install"
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo "✗ Java غير مثبت. يرجى تثبيت Java 17+"
    exit 1
fi

echo "✓ Flutter: $(flutter --version 2>&1 | head -1)"
echo "✓ Java: $(java -version 2>&1 | head -1)"
echo ""

# تنظيف
echo "▸ تنظيف المشروع..."
flutter clean 2>/dev/null || true

# تحميل الاعتماديات
echo "▸ تحميل الاعتماديات..."
flutter pub get

# التحقق من صحة الكود
echo "▸ التحقق من صحة الكود..."
flutter analyze 2>/dev/null || echo "  ⚠ توجد تحذيرات (يمكن تجاهلها)"

# بناء APK
echo ""
echo "▸ بناء APK (إصدار)..."
echo "  قد يستغرق عدة دقائق..."
echo ""

if [ "$1" == "--release" ]; then
    flutter build apk --release --split-per-abi
else
    flutter build apk --debug
fi

# النتيجة
APK_DIR="build/app/outputs/flutter-apk"
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           ✓ تم البناء بنجاح               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "ملفات APK:"
echo ""

if [ -d "$APK_DIR" ]; then
    ls -lh $APK_DIR/*.apk 2>/dev/null || echo "  (لم يتم العثور على APK)"
fi

echo ""
echo "للتثبيت على الجهاز:"
echo "  flutter install"
echo ""
echo "للبناء مع توقيع الإصدار:"
echo "  bash build.sh --release"
echo ""
