import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/dummy_data_service.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedLocationId = 'metro_a';
  String _selectedView = 'hourly'; // hourly or weekly
  List<Map<String, dynamic>>? _apiHourlyData;
  bool _loadingApi = false; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _fetchHourlyFromApi();
  }

  Future<void> _fetchHourlyFromApi() async {
    setState(() => _loadingApi = true);
    try {
      final now = DateTime.now();
      List<Map<String, dynamic>> predictions = [];
      // Prefer realtime-aware prediction for location details, then fall back.
      for (int i = 0; i < 24; i++) {
        final hour = (now.hour + i) % 24;
        final result = await ApiService.getRealtimePrediction(
              locationId: _selectedLocationId,
              hour: hour,
            ) ??
            await ApiService.getPrediction(
              locationId: _selectedLocationId,
              hour: hour,
              dayOfWeek: now.weekday - 1,
              isWeekend: now.weekday >= 6,
              isHoliday: false,
            );
        if (result != null) {
          predictions.add({
            'hour': hour,
            'density': (result['predicted_density'] as num).toDouble(),
            'status': result['status'],
            'label': '${hour.toString().padLeft(2, '0')}:00',
          });
        }
      }
      if (predictions.length == 24) {
        setState(() => _apiHourlyData = predictions);
      }
    } catch (_) {
      // Will use dummy data
    }
    setState(() => _loadingApi = false);
  }

  @override
  Widget build(BuildContext context) {
    final hourlyData =
        _apiHourlyData ??
        DummyDataService.generateHourlyPredictions(_selectedLocationId);
    final weeklyData = DummyDataService.generateWeeklyTrend(
      _selectedLocationId,
    );

    return Container(
      decoration: AppTheme.gradientBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Analytics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Crowd density insights & predictions',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Location Selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLocationId,
                    dropdownColor: AppColors.surfaceDark,
                    style: const TextStyle(color: AppColors.textPrimary),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.neonGreen,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'metro_a',
                        child: Text('Metro Station A'),
                      ),
                      DropdownMenuItem(
                        value: 'metro_b',
                        child: Text('Metro Station B'),
                      ),
                      DropdownMenuItem(
                        value: 'bus_stop_1',
                        child: Text('Central Bus Stop'),
                      ),
                      DropdownMenuItem(
                        value: 'mall_1',
                        child: Text('City Mall'),
                      ),
                      DropdownMenuItem(
                        value: 'park_1',
                        child: Text('Green Park'),
                      ),
                      DropdownMenuItem(
                        value: 'station_1',
                        child: Text('Railway Station'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedLocationId = v;
                          _apiHourlyData = null;
                        });
                        _fetchHourlyFromApi();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle Hourly / Weekly
              Row(
                children: [
                  _TabButton(
                    label: 'Hourly',
                    isActive: _selectedView == 'hourly',
                    onTap: () => setState(() => _selectedView = 'hourly'),
                  ),
                  const SizedBox(width: 8),
                  _TabButton(
                    label: 'Weekly',
                    isActive: _selectedView == 'weekly',
                    onTap: () => setState(() => _selectedView = 'weekly'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Chart
              Container(
                height: 280,
                padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _selectedView == 'hourly'
                    ? _buildHourlyChart(hourlyData)
                    : _buildWeeklyChart(weeklyData),
              ),
              const SizedBox(height: 20),

              // Stats Cards
              const Text(
                'Key Insights',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InsightCard(
                      icon: Icons.trending_up,
                      label: 'Peak Hour',
                      value: _findPeakHour(hourlyData),
                      color: AppColors.crowdHigh,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InsightCard(
                      icon: Icons.trending_down,
                      label: 'Best Hour',
                      value: _findBestHour(hourlyData),
                      color: AppColors.crowdLow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InsightCard(
                      icon: Icons.show_chart,
                      label: 'Average',
                      value: '${_calcAverage(hourlyData).toStringAsFixed(0)}%',
                      color: AppColors.neonCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InsightCard(
                      icon: Icons.people,
                      label: 'Status',
                      value: _getOverallStatus(hourlyData),
                      color: AppColors.neonPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyChart(List<Map<String, dynamic>> data) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${data[group.x]['label']}\n${rod.toY.toStringAsFixed(0)}%',
                const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 3 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data[value.toInt()]['label'],
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 36,
              interval: 25,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.textMuted.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final density = entry.value['density'] as double;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: density,
                width: 8,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _getBarColor(density).withValues(alpha: 0.6),
                    _getBarColor(density),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyChart(List<Map<String, dynamic>> data) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[value.toInt()]['day'],
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 36,
              interval: 25,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.textMuted.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value['avgDensity'] as double,
              );
            }).toList(),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [AppColors.neonCyan, AppColors.neonPurple],
            ),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.neonCyan,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.neonCyan.withValues(alpha: 0.3),
                  AppColors.neonPurple.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(double density) {
    if (density < 40) return AppColors.crowdLow;
    if (density < 70) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }

  String _findPeakHour(List<Map<String, dynamic>> data) {
    final peak = data.reduce(
      (a, b) => (a['density'] as double) > (b['density'] as double) ? a : b,
    );
    return '${peak['label']}';
  }

  String _findBestHour(List<Map<String, dynamic>> data) {
    final best = data.reduce(
      (a, b) => (a['density'] as double) < (b['density'] as double) ? a : b,
    );
    return '${best['label']}';
  }

  double _calcAverage(List<Map<String, dynamic>> data) {
    final sum = data.fold<double>(0, (s, d) => s + (d['density'] as double));
    return sum / data.length;
  }

  String _getOverallStatus(List<Map<String, dynamic>> data) {
    final avg = _calcAverage(data);
    if (avg < 40) return 'Calm';
    if (avg < 70) return 'Moderate';
    return 'Busy';
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.neonGreen.withValues(alpha: 0.15)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.neonGreen : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.neonGreen : AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
