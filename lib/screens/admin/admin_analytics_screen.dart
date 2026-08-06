import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../services/firebase_service.dart';

/// شاشة الإحصائيات — الإيرادات اليومية (7 أيام) + مؤشرات الأداء
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final FirebaseService _firebase = FirebaseService();

  bool _loading = true;
  String? _error;

  // المؤشرات
  double _totalRevenue = 0; // إيراد الطلبات المكتملة
  int _pendingOrders = 0; // طلبات قيد المراجعة
  int _totalPointsRedeemed = 0; // إجمالي النقاط المستخدمة

  // الإيراد اليومي آخر 7 أيام
  List<DateTime> _days = [];
  List<double> _dailyRevenue = [];

  static const List<String> _dayNames = [
    'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد',
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _firebase.getAllOrders();
      if (!mounted) return;

      setState(() {
        // 1) إجمالي الإيراد: مجموع totals الطلبات المكتملة
        _totalRevenue = orders
            .where((o) => o['status'] == 'delivered')
            .fold(0.0, (sum, o) => sum + (o['total'] ?? 0).toDouble());

        // 2) الطلبات قيد المراجعة
        _pendingOrders =
            orders.where((o) => (o['status'] ?? '') == 'pending').length;

        // 3) إجمالي النقاط المستخدمة (خصم الولاء)
        _totalPointsRedeemed = orders.fold(
          0,
          (sum, o) => sum + (((o['pointsUsed'] ?? 0) as num).toInt()),
        );

        // 4) الإيراد اليومي لآخر 7 أيام (الطلبات المكتملة فقط)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        _days = List.generate(
          7,
          (i) => today.subtract(Duration(days: 6 - i)),
        );
        _dailyRevenue = List.filled(7, 0);

        for (final o in orders) {
          if (o['status'] != 'delivered') continue;
          final ts = o['createdAt'];
          if (ts == null) continue;
          final t = DateTime.fromMillisecondsSinceEpoch(
            ts is int ? ts : (ts as num).toInt(),
          );
          final day = DateTime(t.year, t.month, t.day);
          final idx = _days.indexWhere((d) => d.isAtSameMomentAs(day));
          if (idx >= 0) {
            _dailyRevenue[idx] += (o['total'] ?? 0).toDouble();
          }
        }

        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _formatYER(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}م';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}ألف';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإحصائيات'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _loadAnalytics,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 70,
                color: AppColors.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              const Text(
                'تعذر تحميل الإحصائيات',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== بطاقات المؤشرات =====
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  icon: Icons.payments_outlined,
                  label: 'إجمالي الإيرادات',
                  value: '${_totalRevenue.toStringAsFixed(0)}',
                  unit: 'YER',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  icon: Icons.hourglass_top,
                  label: 'طلبات قيد المراجعة',
                  value: '$_pendingOrders',
                  unit: 'طلب',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  icon: Icons.stars_outlined,
                  label: 'نقاط مستخدمة',
                  value: '$_totalPointsRedeemed',
                  unit: 'نقطة',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ===== الرسم البياني: الإيراد اليومي =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'الإيراد اليومي — آخر 7 أيام',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatYER(_dailyRevenue.reduce((a, b) => a + b))} YER',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.border.withValues(alpha: 0.4),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) => Text(
                              _formatYER(value),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= _days.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 6),
                                child: Text(
                                  _dayNames[_days[idx].weekday - 1],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < _dailyRevenue.length; i++)
                              FlSpot(i.toDouble(), _dailyRevenue[i]),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color:
                                AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // وسيلة إيضاح: اليوم + الإيراد
                SizedBox(
                  height: 18,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < _days.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            '${_days[i].day}/${_days[i].month}: '
                            '${_formatYER(_dailyRevenue[i])}',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
