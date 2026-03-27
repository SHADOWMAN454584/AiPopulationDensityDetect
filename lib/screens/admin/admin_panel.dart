import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/dummy_data_service.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  String _selectedLocation = 'metro_a';
  final TextEditingController _hoursController = TextEditingController(
    text: '12',
  );
  bool _blendWithOriginal = true;
  double _weightMaps = 0.6;
  String _trainingStatus = 'idle';
  String? _trainingError;
  int? _lastRowsUsed;
  bool _isSubmittingTraining = false;
  Map<String, dynamic>? _trainingDataInfo;
  Timer? _trainingStatusTimer;

  @override
  void initState() {
    super.initState();
    _loadTrainingStatus();
    _loadTrainingData();
  }

  @override
  void dispose() {
    _trainingStatusTimer?.cancel();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainingStatus() async {
    final statusResult = await ApiService.getRealtimeTrainingStatus();
    if (statusResult == null || !mounted) return;

    final training = statusResult['training'];
    if (training is! Map) return;
    final trainingMap = Map<String, dynamic>.from(training);

    setState(() {
      _trainingStatus = (trainingMap['status'] ?? 'idle').toString();
      _trainingError = trainingMap['last_error']?.toString();
      final rows = trainingMap['last_rows_used'];
      _lastRowsUsed = rows is num ? rows.toInt() : null;
    });

    if (_trainingStatus == 'running') {
      _ensureStatusPolling();
    } else {
      _trainingStatusTimer?.cancel();
      _trainingStatusTimer = null;
    }
  }

  Future<void> _loadTrainingData() async {
    final data = await ApiService.getRealtimeTrainingData();
    if (data == null || !mounted) return;
    setState(() {
      _trainingDataInfo = data;
    });
  }

  void _ensureStatusPolling() {
    if (_trainingStatusTimer != null) return;
    _trainingStatusTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _loadTrainingStatus();
    });
  }

  Future<void> _startTraining() async {
    final parsedHours = int.tryParse(_hoursController.text.trim()) ?? 12;
    if (parsedHours < 1 || parsedHours > 24) {
      _showSnack('hours_to_sample must be between 1 and 24');
      return;
    }
    if (_weightMaps < 0 || _weightMaps > 1) {
      _showSnack('weight_maps must be between 0 and 1');
      return;
    }

    setState(() {
      _isSubmittingTraining = true;
      _trainingError = null;
    });

    final result = await ApiService.startRealtimeTraining(
      hoursToSample: parsedHours,
      blendWithOriginal: _blendWithOriginal,
      weightMaps: _weightMaps,
    );

    if (!mounted) return;

    setState(() {
      _isSubmittingTraining = false;
    });

    if (result == null) {
      _showSnack('Unable to start training right now');
      return;
    }

    final statusCode = result['status_code'];
    if (statusCode == 200) {
      _showSnack('Training started');
      _trainingStatus = 'running';
      _ensureStatusPolling();
      _loadTrainingStatus();
      return;
    }
    if (statusCode == 409) {
      _showSnack('Training already in progress');
      _trainingStatus = 'running';
      _ensureStatusPolling();
      _loadTrainingStatus();
      return;
    }
    if (statusCode == 503) {
      _showSnack('Maps API not configured');
      return;
    }

    _showSnack(
      result['detail']?.toString() ?? 'Training request failed ($statusCode)',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = DummyDataService.generateWeeklyTrend(_selectedLocation);
    final hourlyData = DummyDataService.generateHourlyPredictions(
      _selectedLocation,
    );

    // Compute stats
    final avgDensity =
        hourlyData.fold<double>(0, (s, d) => s + (d['density'] as double)) /
        hourlyData.length;
    final maxDensity = hourlyData.fold<double>(
      0,
      (m, d) => (d['density'] as double) > m ? d['density'] as double : m,
    );

    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                      'Admin Panel',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Transport Authority Dashboard',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
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
                      value: _selectedLocation,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: AppColors.textPrimary),
                      isExpanded: true,
                      items: AppConstants.demoLocations.map((loc) {
                        return DropdownMenuItem(
                          value: loc['id'] as String,
                          child: Text(loc['name'] as String),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedLocation = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Realtime Training Controls
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _statusColor(_trainingStatus).withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Realtime Model Training',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                _trainingStatus,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _trainingStatus.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(_trainingStatus),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _hoursController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'hours_to_sample (1-24)',
                                hintText: '12',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Blend with original',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _blendWithOriginal,
                                  onChanged: _trainingStatus == 'running'
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _blendWithOriginal = v;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'weight_maps: ${_weightMaps.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Slider(
                        value: _weightMaps,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: _weightMaps.toStringAsFixed(2),
                        onChanged: _trainingStatus == 'running'
                            ? null
                            : (v) {
                                setState(() {
                                  _weightMaps = v;
                                });
                              },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _trainingStatus == 'running' ||
                                      _isSubmittingTraining
                                  ? null
                                  : _startTraining,
                              icon: _isSubmittingTraining
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.backgroundDark,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow),
                              label: Text(
                                _isSubmittingTraining
                                    ? 'Starting...'
                                    : 'Start Training',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await _loadTrainingStatus();
                              await _loadTrainingData();
                            },
                            child: const Text('Refresh Status'),
                          ),
                        ],
                      ),
                      if (_lastRowsUsed != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'last_rows_used: $_lastRowsUsed',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_trainingError != null && _trainingError!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Error: $_trainingError',
                            style: const TextStyle(
                              color: AppColors.crowdHigh,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (_trainingDataInfo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'training-data rows: ${_extractTrainingDataRows(_trainingDataInfo!)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Avg Density',
                        value: '${avgDensity.toStringAsFixed(0)}%',
                        icon: Icons.show_chart,
                        color: AppColors.neonCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Peak Density',
                        value: '${maxDensity.toStringAsFixed(0)}%',
                        icon: Icons.trending_up,
                        color: AppColors.crowdHigh,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Locations',
                        value: '${AppConstants.demoLocations.length}',
                        icon: Icons.location_on,
                        color: AppColors.neonPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Prediction Accuracy (simulated)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Model Performance',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MetricRow(label: 'Prediction Accuracy', value: '87.3%'),
                      _MetricRow(
                        label: 'Model Type',
                        value: 'Linear Regression',
                      ),
                      _MetricRow(label: 'Training Samples', value: '2,450'),
                      _MetricRow(label: 'Last Updated', value: 'Today'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly Analytics Chart
                const Text(
                  'Weekly Crowd Analytics',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              if (v.toInt() < weeklyData.length) {
                                return Text(
                                  weeklyData[v.toInt()]['day'],
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
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
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}',
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
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.textMuted.withValues(alpha: 0.1),
                        ),
                      ),
                      barGroups: weeklyData.asMap().entries.map((e) {
                        final d = e.value['avgDensity'] as double;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: d,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.neonPurple,
                                  AppColors.neonCyan,
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Upload CSV Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        color: AppColors.neonPurple.withValues(alpha: 0.7),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload Historical Data',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload CSV files to improve predictions',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'CSV upload coming in Phase 2',
                              ),
                              backgroundColor: AppColors.neonPurple,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.file_upload,
                          color: AppColors.neonPurple,
                        ),
                        label: const Text(
                          'Select CSV File',
                          style: TextStyle(color: AppColors.neonPurple),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.neonPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'running':
        return AppColors.neonCyan;
      case 'completed':
        return AppColors.neonGreen;
      case 'failed':
        return AppColors.crowdHigh;
      default:
        return AppColors.textMuted;
    }
  }

  String _extractTrainingDataRows(Map<String, dynamic> trainingData) {
    if (trainingData['total_rows'] != null) {
      return trainingData['total_rows'].toString();
    }
    if (trainingData['rows'] != null) {
      return trainingData['rows'].toString();
    }
    if (trainingData['data_points'] != null) {
      return trainingData['data_points'].toString();
    }
    return 'available';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
