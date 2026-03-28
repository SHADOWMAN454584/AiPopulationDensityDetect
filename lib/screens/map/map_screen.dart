import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../models/crowd_data.dart';
import '../../services/api_service.dart';

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

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  Map<String, dynamic>? _searchedPlace;
  Map<String, dynamic>? _searchedCrowdData;
  bool _isLoadingCrowdData = false;
  bool _showSearchResults = false;
  String? _searchError;

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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Search Logic ──────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showSearchResults = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(
    String query, {
    bool autoSelectFirst = false,
  }) async {
    if (!mounted) return;

    final results = await ApiService.searchPlaces(
      query,
      latitude: _userPosition?.latitude,
      longitude: _userPosition?.longitude,
    );

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
      _showSearchResults = !autoSelectFirst && results.isNotEmpty;
      _searchError = results.isEmpty ? 'No places found for "$query"' : null;
    });

    if (autoSelectFirst && results.isNotEmpty) {
      await _onPlaceSelected(results.first);
    }
  }

  Future<void> _submitSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    _debounceTimer?.cancel();
    setState(() {
      _isSearching = true;
      _showSearchResults = false;
      _searchError = null;
    });

    await _performSearch(query, autoSelectFirst: true);
  }

  Future<void> _onPlaceSelected(Map<String, dynamic> place) async {
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();

    setState(() {
      _searchedPlace = place;
      _searchedCrowdData = null;
      _isLoadingCrowdData = true;
      _showSearchResults = false;
      _selectedMarker = null;
      _searchController.text = place['name'] ?? '';
      _searchError = null;
    });

    _searchFocusNode.unfocus();

    // Move map to the selected location
    _mapController.move(LatLng(lat, lng), _locatedZoom);

    // Fetch crowd density from backend
    try {
      final crowdResult = await ApiService.getCrowdDensityForLocation(
        latitude: lat,
        longitude: lng,
      );

      if (mounted) {
        setState(() {
          _searchedCrowdData = crowdResult;
          _isLoadingCrowdData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCrowdData = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _searchedPlace = null;
      _searchedCrowdData = null;
      _isLoadingCrowdData = false;
      _showSearchResults = false;
      _searchError = null;
    });
  }

  // ── GPS Logic ─────────────────────────────────────────────────────────────

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
                          fontSize: 18,
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
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Legend
                      _LegendDot(color: AppColors.crowdLow, label: 'Low'),
                      const SizedBox(width: 6),
                      _LegendDot(color: AppColors.crowdMedium, label: 'Medium'),
                      const SizedBox(width: 6),
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
                            initialCenter: _defaultCenter,
                            initialZoom: _defaultZoom,
                            onTap: (_, __) {
                              setState(() {
                                _selectedMarker = null;
                                _showSearchResults = false;
                              });
                              _searchFocusNode.unfocus();
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
                              circles: [
                                ...crowdData.map((data) {
                                  final color = _getHeatColor(
                                    data.crowdDensity,
                                  );
                                  return CircleMarker(
                                    point: LatLng(
                                      data.latitude,
                                      data.longitude,
                                    ),
                                    radius: 30 + (data.crowdDensity / 100) * 30,
                                    color: color.withValues(alpha: 0.3),
                                    borderColor: color.withValues(alpha: 0.6),
                                    borderStrokeWidth: 2,
                                  );
                                }),
                                // Searched place circle
                                if (_searchedPlace != null)
                                  CircleMarker(
                                    point: LatLng(
                                      (_searchedPlace!['lat'] as num)
                                          .toDouble(),
                                      (_searchedPlace!['lng'] as num)
                                          .toDouble(),
                                    ),
                                    radius: 50,
                                    color: AppColors.neonPurple.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderColor: AppColors.neonPurple
                                        .withValues(alpha: 0.5),
                                    borderStrokeWidth: 2,
                                  ),
                              ],
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

                                // ── Searched place marker ────────────────────
                                if (_searchedPlace != null)
                                  Marker(
                                    point: LatLng(
                                      (_searchedPlace!['lat'] as num)
                                          .toDouble(),
                                      (_searchedPlace!['lng'] as num)
                                          .toDouble(),
                                    ),
                                    width: 48,
                                    height: 48,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.neonPurple,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.neonPurple
                                                .withValues(alpha: 0.6),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.search,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),

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

                        // ── Floating Search Bar ─────────────────────────────
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Search input
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _searchFocusNode.hasFocus
                                        ? AppColors.neonCyan.withValues(
                                            alpha: 0.6,
                                          )
                                        : AppColors.textMuted.withValues(
                                            alpha: 0.2,
                                          ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 14),
                                      child: Icon(
                                        Icons.search_rounded,
                                        color: AppColors.neonCyan,
                                        size: 22,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: _submitSearch,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Search any place worldwide...',
                                          hintStyle: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                          filled: false,
                                        ),
                                      ),
                                    ),
                                    if (_isSearching)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.neonCyan,
                                          ),
                                        ),
                                      )
                                    else if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        onPressed: _clearSearch,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Search results dropdown
                              if (_showSearchResults &&
                                  _searchResults.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints: const BoxConstraints(
                                    maxHeight: 260,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark.withValues(
                                      alpha: 0.96,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.neonCyan.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    itemCount: _searchResults.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: AppColors.textMuted.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    itemBuilder: (context, index) {
                                      final result = _searchResults[index];
                                      return _SearchResultTile(
                                        result: result,
                                        onTap: () => _onPlaceSelected(result),
                                      );
                                    },
                                  ),
                                ),

                              if (!_isSearching && _searchError != null)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardDark.withValues(
                                      alpha: 0.94,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.crowdMedium.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: AppColors.crowdMedium,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _searchError!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ── GPS error banner ─────────────────────────────────
                        if (_locationError != null &&
                            !_searchFocusNode.hasFocus)
                          Positioned(
                            top: 76,
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
                          bottom:
                              (_selectedMarker != null ||
                                  _searchedPlace != null)
                              ? 180
                              : 24,
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

                        // ── Searched place info card ─────────────────────────
                        if (_searchedPlace != null && _selectedMarker == null)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: _SearchedPlaceCard(
                              place: _searchedPlace!,
                              crowdData: _searchedCrowdData,
                              isLoading: _isLoadingCrowdData,
                              onClose: _clearSearch,
                            ),
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
// Search Result Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = result['name'] ?? '';
    final displayName = result['display_name'] ?? '';
    final type = result['type'] ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.neonPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.place_rounded,
                  color: AppColors.neonPurple,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (type.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neonCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Searched Place Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchedPlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final Map<String, dynamic>? crowdData;
  final bool isLoading;
  final VoidCallback onClose;

  const _SearchedPlaceCard({
    required this.place,
    required this.crowdData,
    required this.isLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final name = place['name'] ?? 'Unknown';
    final displayName = place['display_name']?.toString() ?? '';
    final lat = (place['lat'] as num?)?.toDouble() ?? 0;
    final lng = (place['lng'] as num?)?.toDouble() ?? 0;

    // Try to extract crowd density and source info from response
    double? crowdDensity;
    String? crowdStatus;
    String? crowdSource;
    int? venuesSampled;
    List<Map<String, dynamic>> nearbyPlaces = [];
    List<Map<String, dynamic>> venueDetails = [];

    if (crowdData != null) {
      // Direct estimation
      crowdDensity =
          _toDouble(crowdData!['crowd_density']) ??
          _toDouble(crowdData!['crowdDensity']);
      crowdStatus = crowdData!['status']?.toString();
      crowdSource = crowdData!['source']?.toString();
      venuesSampled = (crowdData!['venues_sampled'] as num?)?.toInt();

      final details = crowdData!['venue_details'];
      if (details is List && details.isNotEmpty) {
        venueDetails = details
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .take(3)
            .toList();
      }

      // Or from nearby places
      final places =
          crowdData!['nearby_locations'] ??
          crowdData!['places'] ??
          crowdData!['results'];
      if (places is List && places.isNotEmpty) {
        nearbyPlaces = places
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .take(3)
            .toList();
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.place_rounded,
                    color: AppColors.neonPurple,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lat.toStringAsFixed(4)}°, ${lng.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          if (displayName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Crowd data section
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neonCyan,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Fetching crowd density...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (crowdDensity != null)
            // Direct density available
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getDensityColor(crowdDensity).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getDensityColor(crowdDensity).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: _getDensityColor(crowdDensity),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Crowd Density: ${crowdDensity.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _getDensityColor(crowdDensity),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (crowdStatus != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getDensityColor(
                          crowdDensity,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        crowdStatus.toUpperCase(),
                        style: TextStyle(
                          color: _getDensityColor(crowdDensity),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else if (nearbyPlaces.isNotEmpty)
            // Show nearby monitored places
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nearby Monitored Places',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...nearbyPlaces.map((p) {
                  final pName =
                      p['name'] ??
                      p['location_name'] ??
                      p['place_name'] ??
                      'Unknown';
                  final pDensity =
                      _toDouble(p['crowd_density']) ??
                      _toDouble(p['predicted_density']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (pDensity != null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getDensityColor(pDensity),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pName.toString(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (pDensity != null)
                          Text(
                            '${pDensity.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _getDensityColor(pDensity),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            )
          else if (venueDetails.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sampled Venues',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...venueDetails.map((v) {
                  final vName = (v['name'] ?? 'Unknown').toString();
                  final vDensity = _toDouble(v['density']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (vDensity != null)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getDensityColor(vDensity),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (vDensity != null)
                          Text(
                            '${vDensity.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _getDensityColor(vDensity),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            )
          else if (crowdData != null)
            // Got response but no specific data
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textMuted, size: 16),
                SizedBox(width: 8),
                Text(
                  'No crowd data available for this area',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            )
          else
            // No backend response at all
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.crowdMedium.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off, color: AppColors.crowdMedium, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Backend unavailable — connect to get crowd density',
                      style: TextStyle(
                        color: AppColors.crowdMedium,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (!isLoading && crowdData != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (crowdSource != null && crowdSource.isNotEmpty)
                    _InfoChip(
                      label: 'Source: $crowdSource',
                      color: AppColors.neonCyan,
                    ),
                  if (venuesSampled != null)
                    _InfoChip(
                      label: 'Venues: $venuesSampled',
                      color: AppColors.neonPurple,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Color _getDensityColor(double density) {
    if (density < 40) return AppColors.crowdLow;
    if (density < 70) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
