package com.alafif.admin

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alafif.admin/app_launcher"
    private val JEEB_PACKAGE = "com.ahd.jaib"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchJeebPayment" -> {
                    val posNumber = call.argument<String>("posNumber") ?: "573157"
                    val amount = call.argument<String>("amount") ?: "0"
                    val orderId = call.argument<String>("orderId") ?: ""
                    
                    val success = tryAllJeebIntents(posNumber, amount, orderId)
                    result.success(success)
                }
                "diagnoseJeebApp" -> {
                    val info = diagnoseJeebApp()
                    result.success(info)
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    if (packageName.isEmpty()) {
                        result.error("INVALID_ARG", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        packageManager.getPackageInfo(packageName, 0)
                        result.success(true)
                    } catch (e: PackageManager.NameNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** تشخيص تطبيق جيب: قراءة كل الأنشطة والمقاصد */
    private fun diagnoseJeebApp(): String {
        val sb = StringBuilder()
        try {
            val flags = PackageManager.GET_ACTIVITIES or PackageManager.GET_RECEIVERS or PackageManager.GET_SERVICES
            val pi = packageManager.getPackageInfo(JEEB_PACKAGE, flags)
            
            // تطبيق مثبت
            sb.append("✅ Jeeb app installed: ${pi.versionName}")
            
            // الأنشطة (Activities)
            val activities = pi.activities
            if (activities != null) {
                sb.append("\n\n=== Activities (${activities.size}) ===")
                for (a in activities) {
                    sb.append("\n• ${a.name} exported=${a.exported}")
                }
            }
            
            // المستقبلات (Receivers)
            val receivers = pi.receivers
            if (receivers != null) {
                sb.append("\n\n=== Receivers (${receivers.size}) ===")
                for (r in receivers) {
                    sb.append("\n• ${r.name} exported=${r.exported}")
                }
            }
            
            // الخدمات (Services)
            val services = pi.services
            if (services != null) {
                sb.append("\n\n=== Services (${services.size}) ===")
                for (s in services) {
                    sb.append("\n• ${s.name} exported=${s.exported}")
                }
            }
            
            // محاولة فتح الأنشطة المصدرة
            if (activities != null) {
                var triedAny = false
                for (a in activities) {
                    if (a.exported && !a.name.contains("launcher", true) && !a.name.contains("splash", true) && !a.name.contains("main", true)) {
                        triedAny = true
                        try {
                            val intent = Intent().apply {
                                setClassName(JEEB_PACKAGE, a.name)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                putExtra("pos_number", "573157")
                                putExtra("amount", "1000")
                            }
                            startActivity(intent)
                            sb.append("\n\n✅ OPENED: ${a.name}")
                            return sb.toString() // نجح
                        } catch (e: Exception) {
                            sb.append("\n❌ Cannot open ${a.name}: ${e.message?.take(50)}")
                        }
                    }
                }
                if (!triedAny) {
                    sb.append("\n\n⚠️ No exported non-launcher activities found")
                }
            }
            
        } catch (e: Exception) {
            sb.append("\n❌ Diagnosis error: ${e.message}")
        }
        return sb.toString()
    }

    /** يجرب كل الصيغ الممكنة لفتح شاشة الدفع في محفظة جيب */
    private fun tryAllJeebIntents(posNumber: String, amount: String, orderId: String): Boolean {
        // ===== 1. https://jeeb.app مع package (جبري — ما يفتح في المتصفح) =====
        val jeebAppUrls = listOf(
            "https://jeeb.app/pay?pos_number=$posNumber&amount=$amount&order_id=$orderId",
            "https://jeeb.app/payment?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/pos?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/merchant?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/$posNumber/pay?amount=$amount",
            "https://jeeb.app/pay/$posNumber/$amount",
            "https://jeeb.app/payment/$posNumber/$amount",
            "https://www.jeeb.app/pay?pos_number=$posNumber&amount=$amount"
        )
        for (url in jeebAppUrls) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    `package` = JEEB_PACKAGE  // إجباري — يمنع المتصفح من اعتراض الرابط
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                android.util.Log.d("JeebIntent", "✅ jeeb.app: $url")
                return true
            } catch (e: Exception) { }
        }

        // ===== 2. jeeb:// مع package =====
        val paths = listOf("/payment", "/pay", "/purchase", "/pos", "/scan", "/qrcode", "/merchant", "/terminal", "")
        val paramKeys = listOf("pos_number", "pos", "merchant_id", "terminal_id", "store_id", "terminal", "m_id", "t_id")

        for (path in paths) {
            for (paramKey in paramKeys) {
                try {
                    val uriStr = "jeeb:$path?$paramKey=$posNumber&amount=$amount"
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                        `package` = JEEB_PACKAGE
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    android.util.Log.d("JeebIntent", "✅ jeeb://: $uriStr")
                    return true
                } catch (e: Exception) { }
            }
        }

        // ===== 3. jeeb:// بدون package (أي تطبيق) =====
        for (path in paths) {
            try {
                val uriStr = "jeeb:$path?pos_number=$posNumber&amount=$amount"
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null ||
                    packageManager.queryIntentActivities(intent, 0).isNotEmpty()) {
                    startActivity(intent)
                    android.util.Log.d("JeebIntent", "✅ jeeb:// (any app): $uriStr")
                    return true
                }
            } catch (e: Exception) { }
        }

        // ===== 4. افتح التطبيق فقط (home screen) + تشخيص =====
        try {
            val fallbackIntent = packageManager.getLaunchIntentForPackage(JEEB_PACKAGE)
            if (fallbackIntent != null) {
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(fallbackIntent)
                android.util.Log.d("JeebIntent", "ℹ️ Opened Jeeb home screen (no deep link worked)")
                return true
            }
        } catch (e: Exception) { }

        return false
    }
}
