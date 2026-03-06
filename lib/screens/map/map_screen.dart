import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/crowd_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  CrowdData? _selectedMarker;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final crowdData = state.crowdDataList;

        return Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Crowd Heatmap',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Legend
                      _LegendDot(color: AppColors.crowdLow, label: 'Low'),
                      const SizedBox(width: 8),
                      _LegendDot(color: AppColors.crowdMedium, label: 'Medium'),
                      const SizedBox(width: 8),
                      _LegendDot(color: AppColors.crowdHigh, label: 'High'),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: const LatLng(19.0760, 72.8777),
                            initialZoom: 13,
                            onTap: (_, __) {
                              setState(() => _selectedMarker = null);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.crowdsense.ai',
                            ),

                            // Heatmap circles
                            CircleLayer(
                              circles: crowdData.map((data) {
                                final color = _getHeatColor(data.crowdDensity);
                                return CircleMarker(
                                  point: LatLng(data.latitude, data.longitude),
                                  radius: 30 + (data.crowdDensity / 100) * 30,
                                  color: color.withValues(alpha: 0.3),
                                  borderColor: color.withValues(alpha: 0.6),
                                  borderStrokeWidth: 2,
                                );
                              }).toList(),
                            ),

                            // Marker pins
                            MarkerLayer(
                              markers: crowdData.map((data) {
                                return Marker(
                                  point: LatLng(data.latitude, data.longitude),
                                  width: 44,
                                  height: 44,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedMarker = data);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _getHeatColor(data.crowdDensity),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getHeatColor(
                                              data.crowdDensity,
                                            ).withValues(alpha: 0.5),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${data.crowdDensity.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),

                        // Selected marker info
                        if (_selectedMarker != null)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: _MarkerInfoCard(data: _selectedMarker!),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getHeatColor(double density) {
    if (density < 40) return AppColors.crowdLow;
    if (density < 70) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _MarkerInfoCard extends StatelessWidget {
  final CrowdData data;

  const _MarkerInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final statusColor = data.status == 'low'
        ? AppColors.crowdLow
        : data.status == 'medium'
        ? AppColors.crowdMedium
        : AppColors.crowdHigh;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${data.crowdDensity.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.locationName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.crowdCount} people • ${data.status.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (data.predictedNextHour != null)
            Column(
              children: [
                const Text(
                  'Next hr',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
                Text(
                  '${data.predictedNextHour!.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getColor(data.predictedNextHour!),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getColor(double d) {
    if (d < 40) return AppColors.crowdLow;
    if (d < 70) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }
}
