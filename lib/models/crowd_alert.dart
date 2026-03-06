class CrowdAlert {
  final String id;
  final String locationId;
  final String locationName;
  final double threshold; // Notify when crowd < this %
  final bool isActive;
  final DateTime createdAt;

  CrowdAlert({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.threshold,
    this.isActive = true,
    required this.createdAt,
  });

  factory CrowdAlert.fromJson(Map<String, dynamic> json) {
    return CrowdAlert(
      id: json['id'] ?? '',
      locationId: json['location_id'] ?? '',
      locationName: json['location_name'] ?? '',
      threshold: (json['threshold'] ?? 30).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location_id': locationId,
      'location_name': locationName,
      'threshold': threshold,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
