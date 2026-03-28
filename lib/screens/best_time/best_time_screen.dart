import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/dummy_data_service.dart';
import '../../services/api_service.dart';
import '../../constants/app_constants.dart';

class BestTimeScreen extends StatefulWidget {
  const BestTimeScreen({super.key});

  @override
  State<BestTimeScreen> createState() => _BestTimeScreenState();
}

class _BestTimeScreenState extends State<BestTimeScreen> {
  String _fromLocation = 'metro_a';
  String _toLocation = 'metro_b';
  Map<String, dynamic>? _result;
  bool _isLoading = false;

  void _findBestTime() async {
    setState(() => _isLoading = true);

    // Try real API first
    try {
      final apiResult = await ApiService.getBestTravelTime(
        fromLocationId: _fromLocation,
        toLocationId: _toLocation,
      );
      if (apiResult != null) {
        final bestHourRaw = apiResult['best_hour'];
        final fallbackHour = bestHourRaw is num
            ? bestHourRaw.toInt()
            : int.tryParse(bestHourRaw?.toString() ?? '');
        final bestTime =
            (apiResult['best_time'] as String?) ??
            (fallbackHour != null
                ? '${fallbackHour.toString().padLeft(2, '0')}:00'
                : '');

        // Convert API response to match expected format
        setState(() {
          _result = {
            'best_time': bestTime,
            'expected_density': _toDouble(apiResult['expected_density']),
            'status': (apiResult['status'] ?? 'low').toString(),
            'all_predictions': _normalizePredictions(
              apiResult['hourly_predictions'],
            ),
          };
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Fall through to dummy data
    }

    // Fallback to dummy data
    await Future.delayed(const Duration(milliseconds: 400));
    final result = DummyDataService.findBestTravelTime(
      _fromLocation,
      _toLocation,
    );

    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Best Time to Travel',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Find the optimal time with lowest crowd',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // From
                _buildLocationSelector('From', _fromLocation, (v) {
                  setState(() => _fromLocation = v);
                }),
                const SizedBox(height: 12),

                // Swap Icon
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        final temp = _fromLocation;
                        _fromLocation = _toLocation;
                        _toLocation = temp;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: AppColors.neonCyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // To
                _buildLocationSelector('To', _toLocation, (v) {
                  setState(() => _toLocation = v);
                }),
                const SizedBox(height: 24),

                // Find Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _findBestTime,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.backgroundDark,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Analyzing...' : 'Find Best Time'),
                  ),
                ),
                const SizedBox(height: 24),

                // Result
                if (_result != null) ...[
                  // Best Time Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.neonGreen.withValues(alpha: 0.15),
                          AppColors.neonCyan.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.neonGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: AppColors.neonGreen,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Best Time to Travel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _result!['best_time'],
                          style: const TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crowdLow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Expected Crowd: ${_toDouble(_result!['expected_density']).toStringAsFixed(0)}% (${(_result!['status'] ?? 'low').toString().toUpperCase()})',
                            style: const TextStyle(
                              color: AppColors.crowdLow,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hourly Breakdown
                  const Text(
                    'Hourly Crowd Forecast',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildForecastChart(
                      _normalizePredictions(_result!['all_predictions']),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelector(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppColors.surfaceDark,
              style: const TextStyle(color: AppColors.textPrimary),
              isExpanded: true,
              items: AppConstants.demoLocations
                  .map(
                    (loc) => DropdownMenuItem(
                      value: loc['id'] as String,
                      child: Text(loc['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastChart(List<Map<String, dynamic>> predictions) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 4,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < predictions.length) {
                  return Text(
                    (predictions[idx]['label'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              reservedSize: 30,
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
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.textMuted.withValues(alpha: 0.1)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: predictions.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), _toDouble(e.value['density']));
            }).toList(),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [AppColors.neonGreen, AppColors.neonCyan],
            ),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.neonGreen.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _normalizePredictions(dynamic rawPredictions) {
    if (rawPredictions is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawPredictions.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final rawHour = map['hour'];
      final hourValue = rawHour is num
          ? rawHour.toInt()
          : int.tryParse(rawHour?.toString() ?? '');
      final label =
          (map['label'] as String?) ??
          (hourValue != null
              ? '${hourValue.toString().padLeft(2, '0')}:00'
              : '');
      final density = _toDouble(map['density'] ?? map['predicted_density']);

      return {...map, 'hour': hourValue, 'label': label, 'density': density};
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
