class CrowdData {
  final String locationId;
  final String locationName;
  final double latitude;
  final double longitude;
  final int crowdCount;
  final double crowdDensity; // 0-100
  final String status; // low, medium, high
  final DateTime timestamp;
  final double? predictedNextHour;

  CrowdData({
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.crowdCount,
    required this.crowdDensity,
    required this.status,
    required this.timestamp,
    this.predictedNextHour,
  });

  factory CrowdData.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (API) and snake_case (legacy) field names
    return CrowdData(
      locationId: json['locationId'] ?? json['location_id'] ?? '',
      locationName: json['locationName'] ?? json['location_name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      crowdCount: json['crowdCount'] ?? json['crowd_count'] ?? 0,
      crowdDensity: (json['crowdDensity'] ?? json['crowd_density'] ?? 0)
          .toDouble(),
      status: json['status'] ?? 'low',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      predictedNextHour:
          (json['predictedNextHour'] ?? json['predicted_next_hour'])
              ?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'crowd_count': crowdCount,
      'crowd_density': crowdDensity,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'predicted_next_hour': predictedNextHour,
    };
  }

  static String getStatusFromDensity(double density) {
    if (density < 40) return 'low';
    if (density < 70) return 'medium';
    return 'high';
  }
}
