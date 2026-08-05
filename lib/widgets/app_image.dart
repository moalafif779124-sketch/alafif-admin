import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ذاكرة مؤقتة للصور Base64 — تمنع فك التشفير المتكرر لنفس الصورة
final _b64Cache = HashMap<String, Uint8List>();
const int _b64CacheMaxEntries = 50;

/// فك تشفير Base64 في isolate منفصل (خارج الخيط الرئيسي)
Future<Uint8List> _decodeBase64InIsolate(String raw) {
  return compute(_decodeBase64Worker, raw);
}

/// دالة العامل — تُنفَّذ داخل الـ isolate
Uint8List _decodeBase64Worker(String raw) {
  // تنظيف السلسلة: إزالة البادئة data:image/...;base64, والمسافات
  String clean;
  if (raw.contains(',')) {
    clean = raw.split(',').last.trim();
  } else {
    clean = raw.trim();
  }
  clean = clean.replaceAll(RegExp(r'\s'), '');
  return base64Decode(clean);
}

/// أداة لعرض الصور مع معالجة محسّنة للذاكرة:
/// - Base64: ذاكرة مؤقتة LRU + تحميل غير متزامن (عبر compute)
/// - Network: CachedNetworkImage مع memCacheWidth/memCacheHeight إجباري ≤ 300
/// - Placeholder: تأثير Shimmer بدلاً من السبينر
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Color? backgroundColor;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.backgroundColor,
    this.cacheWidth,
    this.cacheHeight,
  });

  // ===== حدود الذاكرة: أقصى حجم 300 بكسل للصور المصغرة =====
  int get _effectiveCacheWidth => (cacheWidth ?? 300).clamp(50, 300);
  int get _effectiveCacheHeight => (cacheHeight ?? 300).clamp(50, 300);

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return _errorWidget();

    if (url.startsWith('data:image/')) {
      return _buildBase64(url);
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return _buildNetwork(url);
    }
    return _errorWidget();
  }

  // ===================== Base64 =====================

  Widget _buildBase64(String url) {
    // عرض الشيمر فوراً أثناء فك التشفير
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _Base64Image(
        rawUrl: url,
        cacheWidth: _effectiveCacheWidth,
        cacheHeight: _effectiveCacheHeight,
        fit: fit,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        errorWidget: _errorWidget(),
        placeholder: _buildPlaceholder(),
      ),
    );
  }

  // ===================== Network =====================

  Widget _buildNetwork(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: _effectiveCacheWidth,
        memCacheHeight: _effectiveCacheHeight,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('🧩 AppImage network error: $error');
          return _errorWidget();
        },
      ),
    );
  }

  // ===================== Placeholder مشترك =====================

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: (width ?? 48) * 0.35,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

// ===================== Widget مساعد لفك Base64 خارج الـ build =====================

class _Base64Image extends StatefulWidget {
  final String rawUrl;
  final int cacheWidth;
  final int cacheHeight;
  final BoxFit fit;
  final double borderRadius;
  final Color? backgroundColor;
  final Widget errorWidget;
  final Widget placeholder;

  const _Base64Image({
    required this.rawUrl,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.fit,
    required this.borderRadius,
    this.backgroundColor,
    required this.errorWidget,
    required this.placeholder,
  });

  @override
  State<_Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<_Base64Image> {
  Uint8List? _bytes;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_Base64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl) {
      _bytes = null;
      _errored = false;
      _decode();
    }
  }

  Future<void> _decode() async {
    try {
      // 1) ابحث في الذاكرة المؤقتة أولاً — صفر معالجة
      final cached = _b64Cache[widget.rawUrl];
      if (cached != null) {
        if (mounted) setState(() => _bytes = cached);
        return;
      }

      // 2) فك التشفير في isolate منفصل — لا يحجب خيط الـ UI
      final bytes = await _decodeBase64InIsolate(widget.rawUrl);

      // 3) خزّن في الذاكرة المؤقتة
      if (_b64Cache.length >= _b64CacheMaxEntries) {
        _b64Cache.remove(_b64Cache.keys.first);
      }
      _b64Cache[widget.rawUrl] = bytes;

      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _errored = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errored) return widget.errorWidget;
    if (_bytes == null) return widget.placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.memory(
        _bytes!,
        width: widget.cacheWidth.toDouble(),
        height: widget.cacheHeight.toDouble(),
        fit: widget.fit,
        filterQuality: FilterQuality.low, // جودة منخفضة للذاكرة
        errorBuilder: (_, __, ___) => widget.errorWidget,
      ),
    );
  }
}
