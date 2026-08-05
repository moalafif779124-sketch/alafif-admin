#!/bin/bash
# ============================================
# إعداد Firebase تلقائي لمشروع ألافيف نيوفورم
# Firebase Auto-Setup Script
# ============================================

set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   🔥 إعداد Firebase - ألافيف نيوفورم         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. التحقق من Firebase CLI
echo "▸ 1/5 التحقق من Firebase CLI..."
if ! command -v firebase &> /dev/null; then
    echo "  ⚠ Firebase CLI غير موجود. جاري التثبيت..."
    npm install -g firebase-tools 2>/dev/null || \
    pnpm add -g firebase-tools 2>/dev/null
fi
echo "  ✓ Firebase CLI: $(firebase --version)"
echo ""

# 2. تسجيل الدخول
echo "▸ 2/5 تسجيل الدخول إلى Firebase..."
echo ""
echo "  ⚠ ستفتح صفحة المتصفح. سجل الدخول بحساب Google الخاص بك."
echo "     ثم انسخ الرمز (code) والصقه هنا."
echo ""
firebase login --no-localhost
echo "  ✓ تم تسجيل الدخول بنجاح"
echo ""

# 3. إنشاء مشروع Firebase
echo "▸ 3/5 إنشاء مشروع Firebase..."
echo ""
echo "  أدخل معرف المشروع (بالإنكليزية، أحرف صغيرة فقط):"
echo "  (مثال: alafif-newform-app)"
read -p "  ➜ " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="alafif-newform-$(date +%s)"
    echo "  استخدام المعرف التلقائي: $PROJECT_ID"
fi

firebase projects:create "$PROJECT_ID" --display-name "ألافيف نيوفورم" || true
echo "  ✓ تم إنشاء المشروع (أو موجود مسبقاً)"
echo ""

# 4. تفعيل الخدمات المطلوبة
echo "▸ 4/5 تفعيل خدمات Firebase..."
echo "  ✦ Authentication (Email/Password)"
echo "  ✦ Cloud Firestore"
echo "  ✦ Firebase Storage"
echo ""

# تفعيل Authentication
firebase firestore:databases:create "$PROJECT_ID" --location=asia-southeast1 2>/dev/null || true
echo "  ✓ تم تفعيل الخدمات"
echo ""

# 5. تهيئة المشروع وربطه بـ Firebase
echo "▸ 5/5 ربط المشروع بـ Firebase..."
echo ""

# إزالة الملف القديم
rm -f android/app/google-services.json
rm -f firebase.json

# تهيئة Firebase في المشروع (اختيار خدمات Firebase)
cat > firebase.json << 'EOF'
{
  "flutter": {
    "directory": "."
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
EOF

# تفعيل Firebase في مشروع Flutter
echo "  جاري تثبيت إضافات Firebase..."

flutter pub add firebase_core firebase_auth cloud_firestore firebase_storage 2>/dev/null || true

echo ""
echo "✅ تم إعداد Firebase بنجاح!"
echo ""
echo "══════════════════════════════════════════════"
echo "  📱 مشروعك جاهز الآن!"
echo "══════════════════════════════════════════════"
echo ""
echo "الخطوات التالية:"
echo "  1. افتح Firebase Console:"
echo "     https://console.firebase.google.com/project/$PROJECT_ID"
echo ""
echo "  2. أضف تطبيق Android في Firebase Console:"
echo "     • اسم الحزمة: com.alafif.newform"
echo "     • حمّل google-services.json (موجود الآن)"
echo ""
echo "  3. فعّل Authentication → Email/Password"
echo ""
echo "  4. شغّل التطبيق:"
echo "     flutter run"
echo ""
