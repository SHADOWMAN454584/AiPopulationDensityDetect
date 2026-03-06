import 'dart:async';
import 'package:flutter/material.dart';
import '../models/crowd_data.dart';
import '../models/crowd_alert.dart';
import '../models/user_model.dart';
import '../services/dummy_data_service.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

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
  Timer? _autoRefreshTimer;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  List<CrowdData> get crowdDataList => _crowdDataList;
  bool get isLoading => _isLoading;
  List<CrowdAlert> get alerts => _alerts;
  String? get selectedLocationId => _selectedLocationId;
  bool get isApiConnected => _isApiConnected;

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
        final bulkResult = await ApiService.getBulkPredictions(
          hour: now.hour,
          dayOfWeek: now.weekday - 1, // API uses 0=Mon
        );

        if (bulkResult != null && bulkResult.isNotEmpty) {
          _crowdDataList = bulkResult.map((pred) {
            final locId = pred['location_id'] as String;
            final density = (pred['predicted_density'] as num).toDouble();
            // Lookup lat/lng from constants
            final locInfo = AppConstants.demoLocations.firstWhere(
              (l) => l['id'] == locId,
              orElse: () => AppConstants.demoLocations.first,
            );
            return CrowdData(
              locationId: locId,
              locationName: pred['location_name'] ?? locInfo['name'],
              latitude: locInfo['lat'],
              longitude: locInfo['lng'],
              crowdCount: (density * 5).round(),
              crowdDensity: density,
              status: CrowdData.getStatusFromDensity(density),
              timestamp: now,
              predictedNextHour: density, // will be refined below
            );
          }).toList();

          // Fetch next-hour predictions
          final nextHourResult = await ApiService.getBulkPredictions(
            hour: (now.hour + 1) % 24,
            dayOfWeek: now.weekday - 1,
          );
          if (nextHourResult != null) {
            for (int i = 0; i < _crowdDataList.length; i++) {
              final nextPred = nextHourResult.firstWhere(
                (p) => p['location_id'] == _crowdDataList[i].locationId,
                orElse: () => <String, dynamic>{},
              );
              if (nextPred.isNotEmpty) {
                _crowdDataList[i] = CrowdData(
                  locationId: _crowdDataList[i].locationId,
                  locationName: _crowdDataList[i].locationName,
                  latitude: _crowdDataList[i].latitude,
                  longitude: _crowdDataList[i].longitude,
                  crowdCount: _crowdDataList[i].crowdCount,
                  crowdDensity: _crowdDataList[i].crowdDensity,
                  status: _crowdDataList[i].status,
                  timestamp: _crowdDataList[i].timestamp,
                  predictedNextHour: (nextPred['predicted_density'] as num)
                      .toDouble(),
                );
              }
            }
          }

          _isLoading = false;
          notifyListeners();
          _checkAlerts();
          return;
        }
      }
    } catch (e) {
      debugPrint('API fetch failed, using dummy data: $e');
    }

    // Fallback to dummy data
    _isApiConnected = false;
    _crowdDataList = DummyDataService.generateCurrentCrowdData();
    _isLoading = false;
    notifyListeners();
    _checkAlerts();
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
