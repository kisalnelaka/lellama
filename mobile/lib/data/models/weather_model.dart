/// Marine weather forecast model for offline caching and UI display.
class WeatherModel {
  final String id;
  final double latitude;
  final double longitude;
  final String locationName;
  final String validForTime;
  final double waveHeight;
  final double waveDirection;
  final double windWaveHeight;
  final double swellWaveHeight;
  final double oceanCurrentVelocity;

  WeatherModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.validForTime,
    required this.waveHeight,
    required this.waveDirection,
    required this.windWaveHeight,
    required this.swellWaveHeight,
    required this.oceanCurrentVelocity,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json, {String defaultLocation = ''}) {
    return WeatherModel(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationName: json['location_name']?.toString() ?? defaultLocation,
      validForTime: json['valid_for_time']?.toString() ?? '',
      waveHeight: (json['wave_height'] as num?)?.toDouble() ?? 0.0,
      waveDirection: (json['wave_direction'] as num?)?.toDouble() ?? 0.0,
      windWaveHeight: (json['wind_wave_height'] as num?)?.toDouble() ?? 0.0,
      swellWaveHeight: (json['swell_wave_height'] as num?)?.toDouble() ?? 0.0,
      oceanCurrentVelocity: (json['ocean_current_velocity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory WeatherModel.fromApiResponse(
    Map<String, dynamic> json, {
    String locationName = '',
    double locLat = 0.0,
    double locLon = 0.0,
  }) {
    return WeatherModel(
      id: json['id']?.toString() ?? 'w-${DateTime.now().microsecondsSinceEpoch}',
      latitude: (json['latitude'] as num?)?.toDouble() ?? locLat,
      longitude: (json['longitude'] as num?)?.toDouble() ?? locLon,
      locationName: json['location_name']?.toString() ?? locationName,
      validForTime: json['valid_for_time']?.toString() ?? '',
      waveHeight: (json['wave_height'] as num?)?.toDouble() ?? 0.0,
      waveDirection: (json['wave_direction'] as num?)?.toDouble() ?? 0.0,
      windWaveHeight: (json['wind_wave_height'] as num?)?.toDouble() ?? 0.0,
      swellWaveHeight: (json['swell_wave_height'] as num?)?.toDouble() ?? 0.0,
      oceanCurrentVelocity: (json['ocean_current_velocity'] as num?)?.toDouble() ?? 0.0,
    );
  }


  factory WeatherModel.fromDbMap(Map<String, dynamic> map) {
    return WeatherModel(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationName: map['location_name'] as String,
      validForTime: map['valid_for_time'] as String,
      waveHeight: (map['wave_height'] as num).toDouble(),
      waveDirection: (map['wave_direction'] as num).toDouble(),
      windWaveHeight: (map['wind_wave_height'] as num).toDouble(),
      swellWaveHeight: (map['swell_wave_height'] as num).toDouble(),
      oceanCurrentVelocity: (map['ocean_current_velocity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'valid_for_time': validForTime,
      'wave_height': waveHeight,
      'wave_direction': waveDirection,
      'wind_wave_height': windWaveHeight,
      'swell_wave_height': swellWaveHeight,
      'ocean_current_velocity': oceanCurrentVelocity,
    };
  }
}
