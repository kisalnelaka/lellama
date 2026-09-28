/// Potential Fishing Zone model representing offline cached coordinates and ocean metrics.
class PFZModel {
  final String id;
  final double latitude;
  final double longitude;
  final double sstCelsius;
  final double sstGradient;
  final double chlorophyll;
  final double confidence;
  final String detectionDate;

  PFZModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.sstCelsius,
    required this.sstGradient,
    required this.chlorophyll,
    required this.confidence,
    required this.detectionDate,
  });

  factory PFZModel.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;

    return PFZModel(
      id: properties['id']?.toString() ?? '',
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
      sstCelsius: (properties['sst_celsius'] as num?)?.toDouble() ?? 28.0,
      sstGradient: (properties['sst_gradient_c_per_km'] as num?)?.toDouble() ?? 0.0,
      chlorophyll: (properties['chlorophyll_mg_m3'] as num?)?.toDouble() ?? 0.0,
      confidence: (properties['confidence'] as num?)?.toDouble() ?? 0.0,
      detectionDate: properties['detection_date']?.toString() ?? '',
    );
  }

  factory PFZModel.fromDbMap(Map<String, dynamic> map) {
    return PFZModel(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      sstCelsius: (map['sst_celsius'] as num).toDouble(),
      sstGradient: (map['sst_gradient'] as num).toDouble(),
      chlorophyll: (map['chlorophyll'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      detectionDate: map['detection_date'] as String,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'sst_celsius': sstCelsius,
      'sst_gradient': sstGradient,
      'chlorophyll': chlorophyll,
      'confidence': confidence,
      'detection_date': detectionDate,
    };
  }
}
