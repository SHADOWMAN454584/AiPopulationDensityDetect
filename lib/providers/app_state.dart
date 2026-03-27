import 'dart:async';
import 'package:flutter/material.dart';
import '../models/crowd_data.dart';
import '../models/crowd_alert.dart';
import '../models/user_model.dart';
import '../services/dummy_data_service.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  // User
  UserModel? _currentUser;
  bool _isLoggedIn = false;

  // Crowd Data
  List<CrowdData> _crowdDataList = [];
  bool _isLoading = false;

  // Alerts
  List<CrowdAlert> _alerts = [];

  // Selected location
  String? _selectedLocationId;

  // API status
  bool _isApiConnected = false;
  bool _googleMapsConfigured = false;
  bool _openAiConfigured = false;
  bool _isUsingRealtimeData = false;
  String _realtimeDataSource = 'none';
  Timer? _autoRefreshTimer;

  // AI Insights
  String? _aiInsights;

  // Locations from server
  List<Map<String, dynamic>> _serverLocations = [];

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  List<CrowdData> get crowdDataList => _crowdDataList;
  bool get isLoading => _isLoading;
  List<CrowdAlert> get alerts => _alerts;
  String? get selectedLocationId => _selectedLocationId;
  bool get isApiConnected => _isApiConnected;
  bool get googleMapsConfigured => _googleMapsConfigured;
  bool get openAiConfigured => _openAiConfigured;
  bool get isUsingRealtimeData => _isUsingRealtimeData;
  String get realtimeDataSource => _realtimeDataSource;
  String? get aiInsights => _aiInsights;
  List<Map<String, dynamic>> get serverLocations => _serverLocations;

  CrowdData? get selectedLocationData {
    if (_selectedLocationId == null) return null;
    try {
      return _crowdDataList.firstWhere(
        (d) => d.locationId == _selectedLocationId,
      );
    } catch (_) {
      return null;
    }
  }

  // Initialize app state
  Future<void> initialize() async {
    _isApiConnected = await ApiService.isApiAvailable();

    if (_isApiConnected) {
      // Get health status to check service configuration
      final health = await ApiService.getHealth();
      if (health != null) {
        _googleMapsConfigured = health['googleMapsConfigured'] ?? false;
        _openAiConfigured = health['openAiConfigured'] ?? false;
      }

      // Load locations from server
      final locations = await ApiService.getLocations();
      if (locations != null) {
        _serverLocations = locations;
      }

      // Get initial crowd data
      await refreshCrowdData();
    } else {
      // Fallback to dummy data
      _crowdDataList = DummyDataService.generateCurrentCrowdData();
    }

    notifyListeners();
  }

  // Auth
  void login(UserModel user) {
    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();
    // Start auto-refresh every 30 seconds
    _startAutoRefresh();
  }

  void logout() {
    _currentUser = null;
    _isLoggedIn = false;
    _autoRefreshTimer?.cancel();
    notifyListeners();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshCrowdData(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Crowd Data — tries real API first, falls back to dummy data
  Future<void> refreshCrowdData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try real API
      _isApiConnected = await ApiService.isApiAvailable();

      if (_isApiConnected) {
        final now = DateTime.now();

        // Get current hour predictions using the new API format
        final predictionsResponse = await ApiService.getBulkPredictions(
          hour: now.hour,
        );

        if (predictionsResponse != null &&
            predictionsResponse['data'] != null) {
          final List<dynamic> dataList = predictionsResponse['data'];

          if (dataList.isNotEmpty) {
            _crowdDataList = dataList
                .map((item) => CrowdData.fromJson(item as Map<String, dynamic>))
                .toList();

            // Try to overlay real-time data if available
            await _tryRealtimeOverlay(now);

            // Load AI insights asynchronously (don't block refresh)
            _loadAiInsightsAsync();

            _isLoading = false;
            notifyListeners();
            _checkAlerts();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('API fetch failed, using dummy data: $e');
    }

    // Fallback to dummy data
    _isApiConnected = false;
    _googleMapsConfigured = false;
    _openAiConfigured = false;
    _isUsingRealtimeData = false;
    _realtimeDataSource = 'none';
    _crowdDataList = DummyDataService.generateCurrentCrowdData();
    _isLoading = false;
    notifyListeners();
    _checkAlerts();
  }

  Future<void> _tryRealtimeOverlay(DateTime now) async {
    _isUsingRealtimeData = false;
    _realtimeDataSource = 'none';

    final status = await ApiService.getRealtimeStatus();
    if (status == null) return;

    final enabled = status['enabled'] == true;
    _googleMapsConfigured = status['provider'] == 'google_maps';

    if (!enabled || !_googleMapsConfigured) return;

    // Try to collect live data
    Map<String, dynamic>? realtimeResponse =
        await ApiService.collectRealtimeData();
    String source = 'live';

    if (realtimeResponse == null) {
      // Fallback to cached data
      realtimeResponse = await ApiService.getCachedRealtimeData();
      source = 'cached';
    }

    if (realtimeResponse == null || realtimeResponse['data'] == null) return;

    // The realtime endpoint returns data in the same format as predictions
    final List<dynamic> realtimeData = realtimeResponse['data'];
    if (realtimeData.isEmpty) return;

    // Replace crowd data with real-time data
    _crowdDataList = realtimeData
        .map((item) => CrowdData.fromJson(item as Map<String, dynamic>))
        .toList();

    _isUsingRealtimeData = true;
    _realtimeDataSource = source;
  }

  Future<void> _loadAiInsightsAsync() async {
    if (!_openAiConfigured) return;

    try {
      final crowdJson = _crowdDataList.map((c) => c.toJson()).toList();
      final insights = await ApiService.getAiInsights(crowdData: crowdJson);
      if (insights != null && insights['summary'] != null) {
        _aiInsights = insights['summary'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading AI insights: $e');
    }
  }

  /// Load AI insights on demand
  Future<void> loadAiInsights() async {
    if (!_isApiConnected) return;

    try {
      final crowdJson = _crowdDataList.map((c) => c.toJson()).toList();
      final insights = await ApiService.getAiInsights(crowdData: crowdJson);
      if (insights != null && insights['summary'] != null) {
        _aiInsights = insights['summary'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading AI insights: $e');
    }
  }

  /// Get AI route advice
  Future<Map<String, dynamic>?> getAiRouteAdvice({
    String? origin,
    String? destination,
  }) async {
    if (!_isApiConnected) return null;

    try {
      final crowdJson = _crowdDataList.map((c) => c.toJson()).toList();
      return await ApiService.getAiRouteAdvice(
        crowdData: crowdJson,
        origin: origin,
        destination: destination,
      );
    } catch (e) {
      debugPrint('Error getting AI route advice: $e');
      return null;
    }
  }

  /// Get directions between two points
  Future<Map<String, dynamic>?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    if (!_isApiConnected || !_googleMapsConfigured) return null;

    return await ApiService.getDirections(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      mode: mode,
    );
  }

  /// Get nearby places
  Future<Map<String, dynamic>?> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 1000,
    String? placeType,
  }) async {
    if (!_isApiConnected || !_googleMapsConfigured) return null;

    return await ApiService.getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      placeType: placeType,
    );
  }

  void selectLocation(String locationId) {
    _selectedLocationId = locationId;
    notifyListeners();
  }

  // Alerts
  void addAlert(CrowdAlert alert) {
    _alerts.add(alert);
    notifyListeners();
  }

  void removeAlert(String alertId) {
    _alerts.removeWhere((a) => a.id == alertId);
    notifyListeners();
  }

  void toggleAlert(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      final alert = _alerts[index];
      _alerts[index] = CrowdAlert(
        id: alert.id,
        locationId: alert.locationId,
        locationName: alert.locationName,
        threshold: alert.threshold,
        isActive: !alert.isActive,
        createdAt: alert.createdAt,
      );
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _triggeredAlerts = [];
  List<Map<String, dynamic>> get triggeredAlerts => _triggeredAlerts;

  void _checkAlerts() {
    _triggeredAlerts = [];
    for (final alert in _alerts) {
      if (!alert.isActive) continue;

      final data = _crowdDataList.where(
        (d) => d.locationId == alert.locationId,
      );
      if (data.isNotEmpty && data.first.crowdDensity <= alert.threshold) {
        _triggeredAlerts.add({
          'alert': alert,
          'current_density': data.first.crowdDensity,
          'message':
              '${alert.locationName} crowd is now ${data.first.crowdDensity.toStringAsFixed(0)}% (below your ${alert.threshold.toStringAsFixed(0)}% threshold)',
        });
      }
    }
    if (_triggeredAlerts.isNotEmpty) {
      notifyListeners();
    }
  }

  void clearTriggeredAlerts() {
    _triggeredAlerts = [];
    notifyListeners();
  }
}
