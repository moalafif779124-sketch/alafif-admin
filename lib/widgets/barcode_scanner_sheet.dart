import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/colors.dart';

/// ورقة مسح كود الصنف (باركود / QR) — تُستخدم في لوحة الإدارة
/// أثناء إضافة منتج لتعبئة الاسم والسعر تلقائياً من كتالوج الأصناف.
///
/// تُفتح كـ bottom sheet منفصلة حتى لا تُهيّأ الكاميرا إلا عند الحاجة،
/// وتُغلق فوراً عند أول قراءة ناجحة وتُوقف الكاميرا.
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  /// يفتح الورقة ويعيد الكود المقروء (أو null عند الإلغاء).
  static Future<String?> open(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BarcodeScannerSheet(),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  late final MobileScannerController _controller;
  final TextEditingController _manualController = TextEditingController();

  bool _handled = false;
  bool _torch = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_handled) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    _controller.stop().catchError((_) {});
    if (mounted) Navigator.of(context).pop(trimmed);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;
    _finish(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (e) {
      debugPrint('⚠️ torch toggle failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.62;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'امسح كود الصنف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torch ? Icons.flash_on : Icons.flash_off,
                      color: _torch ? AppColors.warning : Colors.white70,
                    ),
                    tooltip: 'الفلاش',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      onDetectError: (error, _) {
                        debugPrint('⚠️ scanner error: $error');
                        if (mounted) {
                          setState(() => _cameraError = 'تعذّر تشغيل الكاميرا');
                        }
                      },
                      errorBuilder: (context, error, child) =>
                          _buildCameraError(),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 240,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (_cameraError != null)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Text(
                          _cameraError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onSubmitted: _finish,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'أو أدخل كود الصنف يدوياً',
                        hintStyle: const TextStyle(
                            color: Colors.white38, fontSize: 12.5),
                        filled: true,
                        fillColor: Colors.white10,
                        prefixIcon: const Icon(Icons.keyboard,
                            color: Colors.white38, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _finish(_manualController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('بحث',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError() {
    return Container(
      color: AppColors.textPrimary,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_outlined, color: Colors.white38, size: 40),
          SizedBox(height: 10),
          Text(
            'الكاميرا غير متاحة\nاستخدم الإدخال اليدوي أدناه',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}
