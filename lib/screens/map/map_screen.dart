import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

  // GPS state
  LatLng? _userPosition;
  bool _locationLoading = false;
  String? _locationError;
  bool _hasCenteredOnUser = false; // centre only once on first load

  // ── Default fallback (only used if GPS completely unavailable) ─────────────
  static const LatLng _defaultCenter = LatLng(
    20.5937,
    78.9629,
  ); // centre of India
  static const double _defaultZoom = 5;
  static const double _locatedZoom = 14;

  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  /// Requests GPS permission and fetches device position.
  Future<void> _fetchUserLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      // 1. Location services enabled?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Please turn on GPS in your phone settings.';
          _locationLoading = false;
        });
        return;
      }

      // 2. Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError =
                'Location permission denied. Allow it in app settings.';
            _locationLoading = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permanently denied. Open app settings.';
          _locationLoading = false;
        });
        return;
      }

      // 3. Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userPosition = userLatLng;
        _locationLoading = false;
        _locationError = null;
      });

      // Move map to user's real location (only on first successful fetch)
      if (!_hasCenteredOnUser) {
        _hasCenteredOnUser = true;
        // Small delay lets the map finish its first render before we move it
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _mapController.move(userLatLng, _locatedZoom);
        }
      }
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location. Tap 📍 to retry.';
        _locationLoading = false;
      });
    }
  }

  /// Moves the camera back to the user's current position.
  void _centreOnUser() {
    if (_userPosition != null) {
      _mapController.move(_userPosition!, _locatedZoom);
    } else {
      _fetchUserLocation();
    }
  }

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
                // ── Header ──────────────────────────────────────────────────
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
                      if (state.googleMapsConfigured)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: state.isUsingRealtimeData
                                ? AppColors.neonCyan.withValues(alpha: 0.18)
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: state.isUsingRealtimeData
                                  ? AppColors.neonCyan.withValues(alpha: 0.4)
                                  : AppColors.textMuted.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            state.isUsingRealtimeData
                                ? state.realtimeDataSource == 'cached'
                                      ? 'Maps Cached'
                                      : 'Live Maps'
                                : 'Maps Ready',
                            style: TextStyle(
                              color: state.isUsingRealtimeData
                                  ? AppColors.neonCyan
                                  : AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Legend
                      _LegendDot(color: AppColors.crowdLow, label: 'Low'),
                      const SizedBox(width: 8),
                      _LegendDot(color: AppColors.crowdMedium, label: 'Medium'),
                      const SizedBox(width: 8),
                      _LegendDot(color: AppColors.crowdHigh, label: 'High'),
                    ],
                  ),
                ),

                // ── Map ─────────────────────────────────────────────────────
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
                            // Start at India centre; _fetchUserLocation() will
                            // move the camera to the real device position once
                            // GPS resolves.
                            initialCenter: _defaultCenter,
                            initialZoom: _defaultZoom,
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

                            // ── Heatmap circles ─────────────────────────────
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

                            // ── Location pins ───────────────────────────────
                            MarkerLayer(
                              markers: [
                                // Crowd-density markers
                                ...crowdData.map((data) {
                                  return Marker(
                                    point: LatLng(
                                      data.latitude,
                                      data.longitude,
                                    ),
                                    width: 44,
                                    height: 44,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedMarker = data);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _getHeatColor(
                                            data.crowdDensity,
                                          ),
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
                                }),

                                // ── Blue "you are here" marker ───────────────
                                if (_userPosition != null)
                                  Marker(
                                    point: _userPosition!,
                                    width: 56,
                                    height: 56,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Pulsing outer ring
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blue.withValues(
                                              alpha: 0.15,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.withValues(
                                                alpha: 0.4,
                                              ),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        // Inner dot
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blue,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withValues(
                                                  alpha: 0.6,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // ── GPS error banner ─────────────────────────────────
                        if (_locationError != null)
                          Positioned(
                            top: 12,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade900.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_off,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _locationError!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // ── FAB: locate me ───────────────────────────────────
                        Positioned(
                          bottom: _selectedMarker != null ? 160 : 24,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'locate_me',
                            backgroundColor: AppColors.surfaceDark,
                            onPressed: _locationLoading ? null : _centreOnUser,
                            tooltip: 'Centre on my location',
                            child: _locationLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue,
                                    ),
                                  )
                                : Icon(
                                    _userPosition != null
                                        ? Icons.my_location
                                        : Icons.location_searching,
                                    color: _userPosition != null
                                        ? Colors.blue
                                        : AppColors.textMuted,
                                    size: 20,
                                  ),
                          ),
                        ),

                        // ── Selected marker info card ────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────

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
