import 'package:geolocator/geolocator.dart';

class UserLocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;

  const UserLocationResult({this.latitude, this.longitude, this.error});

  bool get hasLocation => latitude != null && longitude != null;
}

class LocationService {
  static Future<UserLocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const UserLocationResult(
          error: 'Location services are disabled. Please enable GPS.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const UserLocationResult(
          error: 'Location permission denied. Please allow access.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const UserLocationResult(
          error:
              'Location permission permanently denied. Enable it from device settings.',
        );
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      return UserLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return const UserLocationResult(
        error: 'Unable to fetch current location right now.',
      );
    }
  }

  static double distanceInKm({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
    return distanceInMeters / 1000;
  }
}
