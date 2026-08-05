     1|# ألافيف نيوفورم - ALAFIF NEWFORM
     2|
     3|تطبيق متجر إلكتروني للملابس الرجالية الفاخرة - اليمن
     4|
     5|## 🚀 المتطلبات
     6|
     7|- **Flutter SDK** v3.29+ ([تثبيت Flutter](https://flutter.dev/docs/get-started/install))
     8|- **Android SDK** (API 23+)
     9|- **Java** 17+
    10|- **Firebase** مشروع نشط مع تفعيل:
    11|  - Authentication (Email/Password)
    12|  - Cloud Firestore
    13|  - Firebase Storage (للصور)
    14|  - Realtime Database (اختياري)
    15|
    16|## 📦 تثبيت Firebase
    17|
    18|1. أنشئ مشروع Firebase جديد على [console.firebase.google.com](https://console.firebase.google.com)
    19|2. أضف تطبيق Android بمعرف الحزمة: `com.alafif.newform`
    20|3. حمل ملف `google-services.json` وضعه في:
    21|   ```
    22|   android/app/google-services.json
    23|   ```
    24|4. فعّل الخدمات التالية:
    25|   - **Authentication** → Sign-in method → Email/Password
    26|   - **Cloud Firestore** → Create database (وضع اختباري)
    27|   - **Storage** → Setup storage rules
    28|
    29|## 🔧 الإعداد والتشغيل
    30|
    31|### 1. تكوين Firebase
    32|```bash
    33|# نسخ ملف Firebase إلى المشروع
    34|cp ~/Downloads/google-services.json android/app/
    35|```
    36|
    37|### 2. تثبيت الاعتماديات
    38|```bash
    39|flutter pub get
    40|```
    41|
    42|### 3. تشغيل التطبيق (تطوير)
    43|```bash
    44|flutter run
    45|```
    46|
    47|### 4. بناء APK
    48|```bash
    49|# بناء APK تصحيح
    50|flutter build apk --debug
    51|
    52|# بناء APK إصدار (مقسم حسب المعالج)
    53|flutter build apk --release --split-per-abi
    54|
    55|# أو استخدام سكربت البناء
    56|bash build.sh --release
    57|```
    58|
    59|## 📱 APK المخرجات
    60|
    61|بعد البناء، ستجد ملفات APK في:
    62|```
    63|build/app/outputs/flutter-apk/
    64|```
    65|
    66|- `app-arm64-v8a-release.apk` ← للأجهزة الحديثة (64-bit)
    67|- `app-armeabi-v7a-release.apk` ← للأجهزة القديمة (32-bit)
    68|- `app-x86_64-release.apk` ← للمحاكيات
    69|
    70|## 🔑 طرق الدفع المدعومة
    71|
    72|| الطريقة | الحالة |
    73||---------|--------|
    74|| **كريمي باي (Kuraimi Pay)** | ✅ جاهز (يحتاج API key) |
    75|| **جيب (Jeeb)** | ✅ جاهز (يحتاج API key) |
    76|| **الدفع عند الاستلام** | ✅ جاهز |
    77|
    78|### إعداد API للدفع
    79|
    80|في `lib/services/payment_service.dart`:
    81|```dart
    82|// كريمي باي
    83|'Authorization': 'Bearer YOUR_KURAIMI_API_KEY',
    84|
    85|// جيب
    86|'X-API-Key': 'YOUR_JEEB_API_KEY',
    87|```
    88|
    89|## 🎨 العلامة التجارية
    90|
    91|- **اللون الرئيسي**: أزرق بحري غامق `#0D1B3E`
    92|- **اللون الثانوي**: فضي معدني `#C0C0C0`
    93|- **الخط**: Noto Kufi Arabic
    94|- **الاتجاه**: RTL (من اليمين لليسار)
    95|
    96|## 📁 هيكل المشروع
    97|
    98|```
    99|lib/
   100|├── config/          # الإعدادات (الألوان، الثيم، الثوابت)
   101|├── models/          # نماذج البيانات
   102|├── providers/       # إدارة الحالة (Provider)
   103|├── services/        # الخدمات (Firebase, Auth, Payment)
   104|├── screens/         # الشاشات
   105|│   ├── auth/        # تسجيل الدخول والتسجيل
   106|│   ├── cart/        # سلة التسوق
   107|│   ├── catalog/     # المنتجات والتصنيفات
   108|│   ├── checkout/    # إتمام الطلب والدفع
   109|│   ├── home/        # الشاشة الرئيسية
   110|│   └── profile/     # الملف الشخصي والطلبات
   111|├── widgets/         # المكونات القابلة لإعادة الاستخدام
   112|└── utils/           # الأدوات المساعدة
   113|```
   114|
   115|## ✅ الميزات المطبقة
   116|
   117|- [x] شاشة رئيسية مع بانرات وفئات وأحدث المنتجات
   118|- [x] تصفح المنتجات مع فلترة وفرز وبحث
   119|- [x] تفاصيل المنتج مع معرض صور ومقاسات وألوان
   120|- [x] سلة تسوق مع إدارة الكميات
   121|- [x] إتمام الطلب مع اختيار طريقة الدفع
   122|- [x] دعم كريمي باي، جيب، والدفع عند الاستلام
   123|- [x] إنشاء حساب وتسجيل دخول
   124|- [x] إدارة العناوين
   125|- [x] عرض الطلبات السابقة
   126|- [x] دعم كامل للغة العربية و RTL
   127|- [x] قاعدة بيانات Firebase
   128|- [x] تصميم أنيق وراقي بمظهر رجالي
   129|

---

## Build Instructions (GitHub Actions)

This project includes a GitHub Actions workflow for automated APK building.
The connection on Termux is too slow to download the Flutter SDK (~732MB),
so building remotely on GitHub's servers is the recommended approach.

### How to build:

1. **Create a GitHub repository** (github.com/new)
2. **Push this code:**
   ```bash
   cd /path/to/alafif_newform
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

3. **Get your google-services.json from Firebase Console:**
   - Go to https://console.firebase.google.com
   - Open your project → Project Settings → General → Your apps
   - Download android `google-services.json`
   - Replace the placeholder at `android/app/google-services.json`

4. **Push the real google-services.json** or use GitHub Secrets + the workflow.

5. **Wait for build** — go to your repo → Actions tab → workflow runs
   - The build takes ~5-10 minutes
   - APKs will be available as downloadable artifacts

### Download the APKs:
Once the workflow finishes, go to:
- Your repo → Actions → Click the completed run
- Scroll down to **Artifacts** → Download `alafif-newform-apks.zip`

The zip contains:
- `app-armeabi-v7a-release.apk` (older devices)
- `app-arm64-v8a-release.apk` (most modern phones)
- `app-x86_64-release.apk` (emulators)
