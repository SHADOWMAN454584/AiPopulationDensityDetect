import 'dart:math';
import '../models/crowd_data.dart';
import '../constants/app_constants.dart';

/// Generates dummy crowd data for demo/hackathon purposes.
/// Replace with real Supabase calls when backend is connected.
class DummyDataService {
  static final Random _random = Random();

  /// Generate crowd data for all demo locations
  static List<CrowdData> generateCurrentCrowdData() {
    final now = DateTime.now();
    return AppConstants.demoLocations.map((loc) {
      final density = _generateDensityForTime(now.hour, now.weekday);
      return CrowdData(
        locationId: loc['id'],
        locationName: loc['name'],
        latitude: loc['lat'],
        longitude: loc['lng'],
        crowdCount: (density * 5).round(),
        crowdDensity: density,
        status: CrowdData.getStatusFromDensity(density),
        timestamp: now,
        predictedNextHour: _generateDensityForTime(now.hour + 1, now.weekday),
      );
    }).toList();
  }

  /// Simulate crowd density based on hour and day
  static double _generateDensityForTime(int hour, int weekday) {
    double base;

    // Morning rush (7-10)
    if (hour >= 7 && hour <= 10) {
      base = 65 + _random.nextDouble() * 25;
    }
    // Midday (11-15)
    else if (hour >= 11 && hour <= 15) {
      base = 40 + _random.nextDouble() * 20;
    }
    // Evening rush (16-20)
    else if (hour >= 16 && hour <= 20) {
      base = 70 + _random.nextDouble() * 25;
    }
    // Night (21-6)
    else {
      base = 10 + _random.nextDouble() * 20;
    }

    // Weekend reduction
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      base *= 0.7;
    }

    return base.clamp(0, 100);
  }

  /// Generate hourly prediction data for a location (24 hours)
  static List<Map<String, dynamic>> generateHourlyPredictions(
    String locationId,
  ) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> predictions = [];

    for (int i = 0; i < 24; i++) {
      final hour = (now.hour + i) % 24;
      final density = _generateDensityForTime(hour, now.weekday);
      predictions.add({
        'hour': hour,
        'density': density,
        'status': CrowdData.getStatusFromDensity(density),
        'label': '${hour.toString().padLeft(2, '0')}:00',
      });
    }

    return predictions;
  }

  /// Generate weekly trend data
  static List<Map<String, dynamic>> generateWeeklyTrend(String locationId) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.asMap().entries.map((entry) {
      final avgDensity = 40 + _random.nextDouble() * 40;
      return {
        'day': entry.value,
        'dayIndex': entry.key,
        'avgDensity': avgDensity,
        'peakHour': '${8 + _random.nextInt(10)}:00',
      };
    }).toList();
  }

  /// Find best time to travel between two locations
  static Map<String, dynamic> findBestTravelTime(String fromId, String toId) {
    final predictions = generateHourlyPredictions(fromId);
    final sorted = List<Map<String, dynamic>>.from(predictions)
      ..sort(
        (a, b) => (a['density'] as double).compareTo(b['density'] as double),
      );

    final best = sorted.first;
    return {
      'best_time': best['label'],
      'expected_density': best['density'],
      'status': best['status'],
      'all_predictions': predictions,
    };
  }

  /// Suggest alternative route if location is crowded
  static Map<String, dynamic>? suggestAlternative(
    String crowdedLocationId,
    List<CrowdData> allData, {
    Set<String>? allowedLocationIds,
  }) {
    final crowdedLocation = allData.firstWhere(
      (d) => d.locationId == crowdedLocationId,
      orElse: () => allData.first,
    );

    if (crowdedLocation.crowdDensity < 70) return null;
    if (allowedLocationIds != null &&
        !allowedLocationIds.contains(crowdedLocationId)) {
      return null;
    }

    // Find least crowded alternative of same type
    final locationType = AppConstants.demoLocations.firstWhere(
      (l) => l['id'] == crowdedLocationId,
    )['type'];

    final alternatives =
        allData
            .where(
              (d) =>
                  d.locationId != crowdedLocationId &&
                  (allowedLocationIds == null ||
                      allowedLocationIds.contains(d.locationId)) &&
                  AppConstants.demoLocations.any(
                    (l) => l['id'] == d.locationId && l['type'] == locationType,
                  ),
            )
            .toList()
          ..sort((a, b) => a.crowdDensity.compareTo(b.crowdDensity));

    if (alternatives.isEmpty) return null;

    final alt = alternatives.first;
    return {
      'original_id': crowdedLocation.locationId,
      'original': crowdedLocation.locationName,
      'alternative_id': alt.locationId,
      'alternative': alt.locationName,
      'original_density': crowdedLocation.crowdDensity,
      'alternative_density': alt.crowdDensity,
      'savings': crowdedLocation.crowdDensity - alt.crowdDensity,
    };
  }
}
