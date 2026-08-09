import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';

/// تكوين التبويب الواحد
class TabConfig {
  final String id;
  final String labelAr;
  final bool isActive;
  final int order;

  const TabConfig({
    required this.id,
    this.labelAr = '',
    this.isActive = true,
    this.order = 0,
  });

  factory TabConfig.fromMap(Map<String, dynamic> map) {
    return TabConfig(
      id: map['id'] as String? ?? '',
      labelAr: map['labelAr'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'labelAr': labelAr,
        'isActive': isActive,
        'order': order,
      };
}

/// مزود إعدادات التنقل — يقرأ تكوين التبويبات من Firestore
class NavigationProvider with ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();

  List<TabConfig> _tabs = [];
  bool _isLoading = false;
  bool _initialized = false;

  // التبويبات الافتراضية (عند فشل الاتصال أو أول استخدام)
  static const List<TabConfig> defaultTabs = [
    TabConfig(id: 'home', labelAr: 'الرئيسية', isActive: true, order: 0),
    TabConfig(id: 'category', labelAr: 'الفئات', isActive: true, order: 1),
    TabConfig(id: 'live', labelAr: 'المجتمع', isActive: true, order: 2),
    TabConfig(id: 'reels', labelAr: 'اكتشف', isActive: true, order: 3),
    TabConfig(id: 'cart', labelAr: 'السلة', isActive: true, order: 4),
    TabConfig(id: 'profile', labelAr: 'حسابي', isActive: true, order: 5),
  ];

  List<TabConfig> get tabs => _tabs.where((t) => t.isActive).toList();
  List<TabConfig> get allTabs => List.unmodifiable(_tabs);
  bool get isLoading => _isLoading;

  /// تحميل التكوين — من الكاش المحلي فوراً ثم Firestore في الخلفية
  Future<void> load() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();

    // ===== الخطوة 1: اقرأ من الكاش المحلي (صفر انتظار) =====
    final cached = await CacheService.instance.getNavigation();
    if (cached != null && cached['tabs'] is Map) {
      final tabsMap = cached['tabs'] as Map<String, dynamic>;
      _tabs = tabsMap.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        data['id'] = e.key;
        return TabConfig.fromMap(data);
      }).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _isLoading = false;
      notifyListeners();
    }

    // ===== الخطوة 2: حدّث من Firestore في الخلفية =====
    try {
      final config = await _firebase.getNavigationConfig();
      if (config != null && config['tabs'] is Map) {
        final tabsMap = config['tabs'] as Map<String, dynamic>;
        _tabs = tabsMap.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          data['id'] = e.key;
          return TabConfig.fromMap(data);
        }).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        // حفظ في الكاش المحلي
        await CacheService.instance.saveNavigation(config);
      } else {
        _tabs = List.from(defaultTabs);
        // حفظ الافتراضي في Firestore
        await _saveDefaults();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load nav config: $e');
      if (_tabs.isEmpty) _tabs = List.from(defaultTabs);
    }

    _initialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveDefaults() async {
    final tabsMap = <String, Map<String, dynamic>>{};
    for (final tab in defaultTabs) {
      tabsMap[tab.id] = tab.toMap();
    }
    await _firebase.saveNavigationConfig({'tabs': tabsMap});
  }

  /// تبديل حالة التبويب (نشط/غير نشط) — Firestore + محلي
  Future<void> toggleTab(String tabId) async {
    final idx = _tabs.indexWhere((t) => t.id == tabId);
    if (idx < 0) return;

    final updated = TabConfig(
      id: tabId,
      labelAr: _tabs[idx].labelAr,
      isActive: !_tabs[idx].isActive,
      order: _tabs[idx].order,
    );
    _tabs[idx] = updated;
    notifyListeners();

    await _firebase.updateTabConfig(tabId, updated.toMap());
  }

  /// تحديث تسمية التبويب
  Future<void> updateLabel(String tabId, String newLabel) async {
    final idx = _tabs.indexWhere((t) => t.id == tabId);
    if (idx < 0) return;

    final updated = TabConfig(
      id: tabId,
      labelAr: newLabel,
      isActive: _tabs[idx].isActive,
      order: _tabs[idx].order,
    );
    _tabs[idx] = updated;
    notifyListeners();

    await _firebase.updateTabConfig(tabId, updated.toMap());
  }

  /// إعادة تعيين إلى الإعدادات الافتراضية
  Future<void> resetToDefaults() async {
    _tabs = List.from(defaultTabs);
    notifyListeners();
    await _saveDefaults();
  }
}
