import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';

class BestTimeScreen extends StatefulWidget {
  const BestTimeScreen({super.key});

  @override
  State<BestTimeScreen> createState() => _BestTimeScreenState();
}

class _BestTimeScreenState extends State<BestTimeScreen> {
  // Origin
  final TextEditingController _originController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  List<Map<String, dynamic>> _originResults = [];
  Map<String, dynamic>? _selectedOrigin;
  bool _isSearchingOrigin = false;
  bool _showOriginResults = false;

  // Destination
  final TextEditingController _destController = TextEditingController();
  final FocusNode _destFocus = FocusNode();
  List<Map<String, dynamic>> _destResults = [];
  Map<String, dynamic>? _selectedDestination;
  bool _isSearchingDest = false;
  bool _showDestResults = false;

  // Route result
  Map<String, dynamic>? _routeResult;
  bool _isLoading = false;
  String? _error;

  // Travel mode
  String _travelMode = 'driving';

  Timer? _originDebounce;
  Timer? _destDebounce;

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onOriginChanged);
    _destController.addListener(_onDestChanged);
  }

  @override
  void dispose() {
    _originDebounce?.cancel();
    _destDebounce?.cancel();
    _originController.removeListener(_onOriginChanged);
    _destController.removeListener(_onDestChanged);
    _originController.dispose();
    _destController.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onOriginChanged() {
    final q = _originController.text.trim();
    _originDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _originResults = [];
        _isSearchingOrigin = false;
        _showOriginResults = false;
      });
      return;
    }
    setState(() => _isSearchingOrigin = true);
    _originDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlace(q, isOrigin: true);
    });
  }

  void _onDestChanged() {
    final q = _destController.text.trim();
    _destDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _destResults = [];
        _isSearchingDest = false;
        _showDestResults = false;
      });
      return;
    }
    setState(() => _isSearchingDest = true);
    _destDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlace(q, isOrigin: false);
    });
  }

  Future<void> _searchPlace(String query, {required bool isOrigin}) async {
    if (!mounted) return;
    final results = await ApiService.searchPlaces(query);
    if (!mounted) return;

    setState(() {
      if (isOrigin) {
        _originResults = results;
        _isSearchingOrigin = false;
        _showOriginResults = results.isNotEmpty;
      } else {
        _destResults = results;
        _isSearchingDest = false;
        _showDestResults = results.isNotEmpty;
      }
    });
  }

  void _selectPlace(Map<String, dynamic> place, {required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        _selectedOrigin = place;
        _originController.text = place['name'] ?? '';
        _showOriginResults = false;
        _originResults = [];
      } else {
        _selectedDestination = place;
        _destController.text = place['name'] ?? '';
        _showDestResults = false;
        _destResults = [];
      }
      // Reset result when origin/dest changes
      _routeResult = null;
      _error = null;
    });
    if (isOrigin) {
      _originFocus.unfocus();
    } else {
      _destFocus.unfocus();
    }
  }

  void _swapLocations() {
    setState(() {
      final tempPlace = _selectedOrigin;
      final tempText = _originController.text;
      _selectedOrigin = _selectedDestination;
      _originController.text = _destController.text;
      _selectedDestination = tempPlace;
      _destController.text = tempText;
      _routeResult = null;
      _error = null;
    });
  }

  Future<void> _findFastestRoute() async {
    if (_selectedOrigin == null || _selectedDestination == null) {
      setState(() => _error = 'Please select both origin and destination.');
      return;
    }

    final originLat = (_selectedOrigin!['lat'] as num).toDouble();
    final originLng = (_selectedOrigin!['lng'] as num).toDouble();
    final destLat = (_selectedDestination!['lat'] as num).toDouble();
    final destLng = (_selectedDestination!['lng'] as num).toDouble();
    final originName = (_selectedOrigin!['name'] ?? '').toString();
    final destName = (_selectedDestination!['name'] ?? '').toString();

    setState(() {
      _isLoading = true;
      _error = null;
      _routeResult = null;
    });

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    try {
      final result = await ApiService.getAiSmartRoute(
        originName: originName,
        originLat: originLat,
        originLng: originLng,
        destinationName: destName,
        destLat: destLat,
        destLng: destLng,
        mode: _travelMode,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _routeResult = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Could not find a route. Check your connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Route analysis failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          body: Container(
            decoration: AppTheme.gradientBackground,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _showOriginResults = false;
                    _showDestResults = false;
                  });
                },
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
                          const Expanded(
                            child: Text(
                              'AI Route Planner',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Live/Demo badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: state.isApiConnected
                                  ? AppColors.neonGreen.withValues(alpha: 0.15)
                                  : AppColors.crowdMedium
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: state.isApiConnected
                                      ? AppColors.neonGreen
                                      : AppColors.crowdMedium,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  state.isApiConnected ? 'AI Live' : 'Demo',
                                  style: TextStyle(
                                    color: state.isApiConnected
                                        ? AppColors.neonGreen
                                        : AppColors.crowdMedium,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'Search any place worldwide and find the fastest crowd-aware route',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Origin search ──────────────────────────────
                      _buildSearchField(
                        label: 'Starting Point',
                        icon: Icons.trip_origin_rounded,
                        iconColor: AppColors.neonGreen,
                        controller: _originController,
                        focusNode: _originFocus,
                        isSearching: _isSearchingOrigin,
                        selected: _selectedOrigin,
                        results: _originResults,
                        showResults: _showOriginResults,
                        onSelect: (p) => _selectPlace(p, isOrigin: true),
                        onClear: () {
                          _originController.clear();
                          setState(() {
                            _selectedOrigin = null;
                            _routeResult = null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // ── Swap ───────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _swapLocations,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.neonCyan.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.neonCyan
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.swap_vert_rounded,
                              color: AppColors.neonCyan,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Destination search ─────────────────────────
                      _buildSearchField(
                        label: 'Destination',
                        icon: Icons.place_rounded,
                        iconColor: AppColors.crowdHigh,
                        controller: _destController,
                        focusNode: _destFocus,
                        isSearching: _isSearchingDest,
                        selected: _selectedDestination,
                        results: _destResults,
                        showResults: _showDestResults,
                        onSelect: (p) => _selectPlace(p, isOrigin: false),
                        onClear: () {
                          _destController.clear();
                          setState(() {
                            _selectedDestination = null;
                            _routeResult = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Travel mode selector ──────────────────────
                      Row(
                        children: [
                          _ModeChip(
                            icon: Icons.directions_car_rounded,
                            label: 'Drive',
                            selected: _travelMode == 'driving',
                            onTap: () =>
                                setState(() => _travelMode = 'driving'),
                          ),
                          const SizedBox(width: 8),
                          _ModeChip(
                            icon: Icons.directions_walk_rounded,
                            label: 'Walk',
                            selected: _travelMode == 'walking',
                            onTap: () =>
                                setState(() => _travelMode = 'walking'),
                          ),
                          const SizedBox(width: 8),
                          _ModeChip(
                            icon: Icons.directions_transit_rounded,
                            label: 'Transit',
                            selected: _travelMode == 'transit',
                            onTap: () =>
                                setState(() => _travelMode = 'transit'),
                          ),
                          const SizedBox(width: 8),
                          _ModeChip(
                            icon: Icons.directions_bike_rounded,
                            label: 'Bike',
                            selected: _travelMode == 'bicycling',
                            onTap: () =>
                                setState(() => _travelMode = 'bicycling'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Find Route button ─────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading ||
                                  _selectedOrigin == null ||
                                  _selectedDestination == null)
                              ? null
                              : _findFastestRoute,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.backgroundDark,
                                  ),
                                )
                              : const Icon(Icons.route_rounded),
                          label: Text(
                            _isLoading
                                ? 'Analyzing Routes...'
                                : 'Find Fastest Route',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // ── Error ─────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.crowdHigh
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.crowdHigh
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.crowdHigh, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.crowdHigh,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Results ───────────────────────────────────
                      if (_routeResult != null) ...[
                        const SizedBox(height: 24),
                        _buildRouteResults(_routeResult!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Search Field Widget
  // ────────────────────────────────────────────────────────────

  Widget _buildSearchField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isSearching,
    required Map<String, dynamic>? selected,
    required List<Map<String, dynamic>> results,
    required bool showResults,
    required ValueChanged<Map<String, dynamic>> onSelect,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected != null
                  ? iconColor.withValues(alpha: 0.4)
                  : focusNode.hasFocus
                      ? AppColors.neonCyan.withValues(alpha: 0.4)
                      : AppColors.textMuted.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search $label...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    filled: false,
                  ),
                ),
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neonCyan,
                    ),
                  ),
                )
              else if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
        // Selected info chip
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: iconColor, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (selected['display_name'] ?? selected['name'] ?? '')
                        .toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: iconColor.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Dropdown results
        if (showResults && results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.cardDark.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.textMuted.withValues(alpha: 0.1),
              ),
              itemBuilder: (context, i) {
                final r = results[i];
                return InkWell(
                  onTap: () => onSelect(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.neonPurple
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.place_rounded,
                              color: AppColors.neonPurple,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (r['name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                (r['display_name'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // Route Results Display
  // ────────────────────────────────────────────────────────────

  Widget _buildRouteResults(Map<String, dynamic> result) {
    final aiAdvice = (result['ai_advice'] ??
            result['advice'] ??
            result['summary'] ??
            '')
        .toString();
    final bestTime = (result['best_time'] ?? '').toString();
    final routes = _extractList(result['routes']);
    final recommendations = _extractList(result['recommendations']);

    // Crowd info
    final originCrowd = result['origin_crowd'];
    final destCrowd = result['destination_crowd'];
    final originDensity = _toDouble(
      originCrowd?['crowd_density'] ?? originCrowd?['crowdDensity'],
    );
    final destDensity = _toDouble(
      destCrowd?['crowd_density'] ?? destCrowd?['crowdDensity'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── AI Advice Card ──────────────────────────────────────
        if (aiAdvice.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonPurple.withValues(alpha: 0.12),
                  AppColors.neonCyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.neonPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.neonPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI Route Advice',
                      style: TextStyle(
                        color: AppColors.neonPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  aiAdvice,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // ── Best time card ──────────────────────────────────────
        if (bestTime.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonGreen.withValues(alpha: 0.12),
                  AppColors.neonCyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.neonGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: AppColors.neonGreen, size: 32),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Best Time to Depart',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      bestTime,
                      style: const TextStyle(
                        color: AppColors.neonGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ── Crowd density at origin & dest ──────────────────────
        if (originDensity > 0 || destDensity > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (originDensity > 0)
                Expanded(
                  child: _CrowdChip(
                    label: 'Origin Crowd',
                    density: originDensity,
                  ),
                ),
              if (originDensity > 0 && destDensity > 0)
                const SizedBox(width: 12),
              if (destDensity > 0)
                Expanded(
                  child: _CrowdChip(
                    label: 'Dest. Crowd',
                    density: destDensity,
                  ),
                ),
            ],
          ),
        ],

        // ── Route options ───────────────────────────────────────
        if (routes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Route Options',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...routes.asMap().entries.map((entry) {
            final i = entry.key;
            final route = entry.value;
            return _RouteOptionCard(index: i, route: route);
          }),
        ],

        // ── Recommendations ─────────────────────────────────────
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Recommendations',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...recommendations.map((rec) {
            final text = rec is Map
                ? (rec['text'] ?? rec['recommendation'] ?? rec.toString())
                    .toString()
                : rec.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.lightbulb_outline,
                        color: AppColors.crowdMedium, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  List<dynamic> _extractList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Travel Mode Chip
// ─────────────────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: 0.15)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.neonCyan.withValues(alpha: 0.5)
                  : AppColors.textMuted.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.neonCyan : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.neonCyan : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Crowd Chip
// ─────────────────────────────────────────────────────────────────────────────

class _CrowdChip extends StatelessWidget {
  final String label;
  final double density;

  const _CrowdChip({required this.label, required this.density});

  Color get _color {
    if (density < 40) return AppColors.crowdLow;
    if (density < 70) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${density.toStringAsFixed(0)}%',
            style: TextStyle(
              color: _color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Option Card
// ─────────────────────────────────────────────────────────────────────────────

class _RouteOptionCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> route;

  const _RouteOptionCard({required this.index, required this.route});

  @override
  Widget build(BuildContext context) {
    final duration = route['duration'] ?? route['travel_time'] ?? '';
    final distance = route['distance'] ?? '';
    final summary = route['summary'] ?? route['via'] ?? '';
    final warnings = route['warnings'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: index == 0
            ? AppColors.neonGreen.withValues(alpha: 0.06)
            : AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: index == 0
              ? AppColors.neonGreen.withValues(alpha: 0.3)
              : AppColors.textMuted.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: index == 0
                      ? AppColors.neonGreen.withValues(alpha: 0.15)
                      : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  index == 0 ? '⚡ Fastest' : 'Route ${index + 1}',
                  style: TextStyle(
                    color: index == 0
                        ? AppColors.neonGreen
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (duration.toString().isNotEmpty)
                Text(
                  duration.toString(),
                  style: TextStyle(
                    color: index == 0
                        ? AppColors.neonGreen
                        : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (distance.toString().isNotEmpty || summary.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (distance.toString().isNotEmpty) ...[
                    const Icon(Icons.straighten,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      distance.toString(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (distance.toString().isNotEmpty &&
                      summary.toString().isNotEmpty)
                    const Text(' • ',
                        style: TextStyle(color: AppColors.textMuted)),
                  if (summary.toString().isNotEmpty)
                    Expanded(
                      child: Text(
                        'via $summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (warnings != null && warnings.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.crowdMedium, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      warnings.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.crowdMedium,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
