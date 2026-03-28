import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/crowd_data.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/dummy_data_service.dart';
import '../../services/location_service.dart';

class SmartRouteScreen extends StatefulWidget {
  const SmartRouteScreen({super.key});

  @override
  State<SmartRouteScreen> createState() => _SmartRouteScreenState();
}

class _SmartRouteScreenState extends State<SmartRouteScreen> {
  bool _isLocating = false;
  bool _isLoadingNearbySmartRoute = false;
  bool _hasLoadedNearbyApi = false;
  double? _apiRadiusKm;
  double? _userLatitude;
  double? _userLongitude;
  String? _locationError;
  List<Map<String, dynamic>> _apiNearbyLocations = [];
  List<Map<String, dynamic>> _apiSuggestions = [];

  @override
  void initState() {
    super.initState();
    _refreshUserLocation();
  }

  Future<void> _refreshUserLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
      _hasLoadedNearbyApi = false;
      _apiNearbyLocations = [];
      _apiSuggestions = [];
      _apiRadiusKm = null;
    });

    final result = await LocationService.getCurrentLocation();

    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _userLatitude = result.latitude;
      _userLongitude = result.longitude;
      _locationError = result.error;
    });

    if (result.hasLocation) {
      await _loadNearbySmartRoute();
    }
  }

  Future<void> _loadNearbySmartRoute() async {
    if (_userLatitude == null || _userLongitude == null) return;

    setState(() {
      _isLoadingNearbySmartRoute = true;
    });

    final response = await ApiService.getNearbySmartRoute(
      latitude: _userLatitude!,
      longitude: _userLongitude!,
      radiusKm: AppConstants.smartRouteRadiusKm,
    );

    if (!mounted) return;

    if (response != null) {
      setState(() {
        _isLoadingNearbySmartRoute = false;
        _hasLoadedNearbyApi = true;
        _apiRadiusKm = (response['radius_km'] as num?)?.toDouble();
        _apiNearbyLocations = _toMapList(response['nearby_locations']);
        _apiSuggestions = _toMapList(response['suggestions']);
      });
      return;
    }

    setState(() {
      _isLoadingNearbySmartRoute = false;
      _hasLoadedNearbyApi = false;
      _apiNearbyLocations = [];
      _apiSuggestions = [];
      _apiRadiusKm = null;
    });
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  _NearbyLocationData _buildNearbyLocationData() {
    final userLat = _userLatitude!;
    final userLng = _userLongitude!;
    final nearbyLocationIds = <String>{};
    final distanceByLocationId = <String, double>{};

    for (final location in AppConstants.demoLocations) {
      final locationId = location['id'] as String;
      final latitude = (location['lat'] as num).toDouble();
      final longitude = (location['lng'] as num).toDouble();
      final distanceKm = LocationService.distanceInKm(
        fromLatitude: userLat,
        fromLongitude: userLng,
        toLatitude: latitude,
        toLongitude: longitude,
      );

      if (distanceKm <= AppConstants.smartRouteRadiusKm) {
        nearbyLocationIds.add(locationId);
        distanceByLocationId[locationId] = distanceKm;
      }
    }

    return _NearbyLocationData(
      locationIds: nearbyLocationIds,
      distanceByLocationId: distanceByLocationId,
    );
  }

  List<Map<String, dynamic>> _buildFallbackNearbyLocations(
    List<CrowdData> crowdData,
    _NearbyLocationData nearbyData,
  ) {
    final nearbyLocations =
        crowdData
            .where((d) => nearbyData.locationIds.contains(d.locationId))
            .map(
              (d) => {
                'location_id': d.locationId,
                'location_name': d.locationName,
                'distance_km': nearbyData.distanceByLocationId[d.locationId],
                'predicted_density': d.crowdDensity,
                'status': d.status,
              },
            )
            .toList()
          ..sort(
            (a, b) => _toDouble(
              a['distance_km'],
            ).compareTo(_toDouble(b['distance_km'])),
          );

    return nearbyLocations;
  }

  List<Map<String, dynamic>> _normalizeApiSuggestions(
    List<Map<String, dynamic>> apiSuggestions,
  ) {
    return apiSuggestions
        .map(
          (s) => {
            'original_id': s['original_location_id'] ?? s['original_id'],
            'original':
                s['original_location_name'] ?? s['original'] ?? 'Unknown',
            'original_density': _toDouble(s['original_density']),
            'original_distance_km': s['original_distance_km'],
            'alternative_id':
                s['alternative_location_id'] ?? s['alternative_id'],
            'alternative':
                s['alternative_location_name'] ?? s['alternative'] ?? 'Unknown',
            'alternative_density': _toDouble(s['alternative_density']),
            'alternative_distance_km': s['alternative_distance_km'],
            'savings': _toDouble(s['savings']),
            'fastest_route_minutes': s['fastest_route_minutes'],
            'fastest_route_distance_km': s['fastest_route_distance_km'],
            'route_source': s['route_source'],
            'selection_source': s['selection_source'],
            'ai_reason': s['ai_reason'],
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Consumer<AppState>(
            builder: (context, state, _) {
              final crowdData = state.crowdDataList;
              final hasUserLocation =
                  _userLatitude != null && _userLongitude != null;
              final nearbyData = hasUserLocation
                  ? _buildNearbyLocationData()
                  : null;
              final effectiveRadiusKm =
                  _apiRadiusKm ?? AppConstants.smartRouteRadiusKm;
              final radiusLabel = effectiveRadiusKm.toStringAsFixed(0);

              final fallbackSuggestions = <Map<String, dynamic>>[];
              if (nearbyData != null) {
                for (final data in crowdData) {
                  final suggestion = DummyDataService.suggestAlternative(
                    data.locationId,
                    crowdData,
                    allowedLocationIds: nearbyData.locationIds,
                  );
                  if (suggestion != null) {
                    final originalId = suggestion['original_id'] as String?;
                    final alternativeId =
                        suggestion['alternative_id'] as String?;

                    fallbackSuggestions.add(suggestion);
                    if (originalId != null) {
                      fallbackSuggestions.last['original_distance_km'] =
                          nearbyData.distanceByLocationId[originalId];
                    }
                    if (alternativeId != null) {
                      fallbackSuggestions.last['alternative_distance_km'] =
                          nearbyData.distanceByLocationId[alternativeId];
                    }
                  }
                }
              }

              final fallbackNearbyLocations = nearbyData == null
                  ? <Map<String, dynamic>>[]
                  : _buildFallbackNearbyLocations(crowdData, nearbyData);

              final useApiData = _hasLoadedNearbyApi;
              final nearbyLocations = useApiData
                  ? _apiNearbyLocations
                  : fallbackNearbyLocations;
              final suggestions = useApiData
                  ? _normalizeApiSuggestions(_apiSuggestions)
                  : fallbackSuggestions;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Route',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI-powered crowd avoidance',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.2),
                        ),
                      ),
                      child: _isLocating
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.neonCyan,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Detecting your location for $radiusLabel km smart suggestions...',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      hasUserLocation
                                          ? Icons.my_location
                                          : Icons.location_off,
                                      color: hasUserLocation
                                          ? AppColors.neonGreen
                                          : AppColors.crowdHigh,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        hasUserLocation
                                            ? '${nearbyLocations.length} monitored locations found within $radiusLabel km (${useApiData ? 'backend' : 'local fallback'})'
                                            : (_locationError ??
                                                  'Location unavailable. Smart Route is limited until location is enabled.'),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (hasUserLocation)
                                      IconButton(
                                        onPressed: _isLoadingNearbySmartRoute
                                            ? null
                                            : _loadNearbySmartRoute,
                                        icon: const Icon(
                                          Icons.sync,
                                          color: AppColors.neonCyan,
                                          size: 18,
                                        ),
                                        tooltip: 'Refresh nearby smart route',
                                      )
                                    else
                                      TextButton(
                                        onPressed: _refreshUserLocation,
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: AppColors.neonCyan,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (hasUserLocation &&
                                    _isLoadingNearbySmartRoute)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6, left: 28),
                                    child: Text(
                                      'Refreshing nearby smart routes from backend...',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_isLocating &&
                      hasUserLocation &&
                      nearbyLocations.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Nearby monitored places',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (!_isLocating &&
                      hasUserLocation &&
                      nearbyLocations.isNotEmpty)
                    const SizedBox(height: 8),
                  if (!_isLocating &&
                      hasUserLocation &&
                      nearbyLocations.isNotEmpty)
                    SizedBox(
                      height: 105,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: nearbyLocations.length,
                        itemBuilder: (context, index) {
                          return _NearbyLocationCard(
                            location: nearbyLocations[index],
                          );
                        },
                      ),
                    ),
                  if (!_isLocating &&
                      hasUserLocation &&
                      nearbyLocations.isNotEmpty)
                    const SizedBox(height: 8),
                  const SizedBox(height: 4),
                  Expanded(
                    child: _isLocating
                        ? const Center(
                            child: Text(
                              'Finding nearby locations...',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : !hasUserLocation
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_disabled,
                                    color: AppColors.crowdHigh.withValues(
                                      alpha: 0.6,
                                    ),
                                    size: 58,
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Location required',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Enable location to get Smart Route alternatives within $radiusLabel km of you.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    onPressed: _refreshUserLocation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.neonCyan,
                                      foregroundColor: AppColors.backgroundDark,
                                    ),
                                    child: const Text('Use my location'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : nearbyLocations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_searching,
                                    color: AppColors.neonCyan.withValues(
                                      alpha: 0.5,
                                    ),
                                    size: 60,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No nearby monitored locations',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No monitored location found within $radiusLabel km from your current position.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.crowdLow.withValues(
                                    alpha: 0.5,
                                  ),
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'All clear!',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No crowded nearby locations detected within $radiusLabel km',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final s = suggestions[index];
                              return _RouteCard(suggestion: s);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;

  const _RouteCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final savings = _toDouble(suggestion['savings']);
    final originalDistanceKm = (suggestion['original_distance_km'] as num?)
        ?.toDouble();
    final alternativeDistanceKm =
        (suggestion['alternative_distance_km'] as num?)?.toDouble();
    final fastestRouteMinutes = (suggestion['fastest_route_minutes'] as num?)
        ?.toDouble();
    final fastestRouteDistanceKm =
        (suggestion['fastest_route_distance_km'] as num?)?.toDouble();
    final routeSource = suggestion['route_source'] as String?;
    final selectionSource = suggestion['selection_source'] as String?;
    final aiReason = suggestion['ai_reason'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.crowdHigh.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: AppColors.crowdHigh,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${suggestion['original']}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Crowd: ${_toDouble(suggestion['original_density']).toStringAsFixed(0)}% (HIGH)',
                      style: const TextStyle(
                        color: AppColors.crowdHigh,
                        fontSize: 12,
                      ),
                    ),
                    if (originalDistanceKm != null)
                      Text(
                        '${originalDistanceKm.toStringAsFixed(1)} km from you',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Column(
                  children: [
                    Container(
                      width: 2,
                      height: 20,
                      color: AppColors.neonCyan.withValues(alpha: 0.3),
                    ),
                    const Icon(
                      Icons.arrow_downward,
                      color: AppColors.neonCyan,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${savings.toStringAsFixed(0)}% less crowded',
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.crowdLow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.crowdLow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${suggestion['alternative']}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Crowd: ${_toDouble(suggestion['alternative_density']).toStringAsFixed(0)}% (LOW)',
                      style: const TextStyle(
                        color: AppColors.crowdLow,
                        fontSize: 12,
                      ),
                    ),
                    if (alternativeDistanceKm != null)
                      Text(
                        '${alternativeDistanceKm.toStringAsFixed(1)} km from you',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (fastestRouteMinutes != null ||
              fastestRouteDistanceKm != null ||
              aiReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fastestRouteMinutes != null ||
                        fastestRouteDistanceKm != null)
                      Text(
                        'Fastest route: '
                        '${fastestRouteMinutes?.toStringAsFixed(0) ?? '--'} min, '
                        '${fastestRouteDistanceKm?.toStringAsFixed(1) ?? '--'} km',
                        style: const TextStyle(
                          color: AppColors.neonCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (aiReason != null && aiReason.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          aiReason,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (routeSource != null || selectionSource != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'route: ${routeSource ?? 'n/a'} | selection: ${selectionSource ?? 'n/a'}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyLocationCard extends StatelessWidget {
  final Map<String, dynamic> location;

  const _NearbyLocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final density = _toDouble(location['predicted_density']);
    final status = _normalizeStatus(location['status'], density: density);
    final statusColor = _statusColor(status);
    final distanceKm = _toDouble(location['distance_km']);

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${location['location_name'] ?? 'Unknown'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '${distanceKm.toStringAsFixed(1)} km away',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          Row(
            children: [
              Text(
                '${density.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyLocationData {
  final Set<String> locationIds;
  final Map<String, double> distanceByLocationId;

  const _NearbyLocationData({
    required this.locationIds,
    required this.distanceByLocationId,
  });
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _normalizeStatus(dynamic rawStatus, {required double density}) {
  final normalized = rawStatus?.toString().toLowerCase() ?? '';
  if (normalized == 'low' || normalized == 'medium' || normalized == 'high') {
    return normalized;
  }
  return CrowdData.getStatusFromDensity(density);
}

Color _statusColor(String status) {
  switch (status) {
    case 'high':
      return AppColors.crowdHigh;
    case 'medium':
      return AppColors.crowdMedium;
    default:
      return AppColors.crowdLow;
  }
}
