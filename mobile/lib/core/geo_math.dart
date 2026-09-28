import 'dart:math' as math;

/// Great-circle navigation mathematics for maritime offshore routing.
class GeoMath {
  static const double earthRadiusKm = 6371.0;
  static const double kmToNauticalMiles = 0.539957;

  /// Calculate great-circle distance between two coordinates in Nautical Miles (NM).
  static double distanceInNauticalMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceKm = earthRadiusKm * c;
    return distanceKm * kmToNauticalMiles;
  }

  /// Calculate initial compass bearing from Point 1 to Point 2 in degrees (0 - 360°).
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);
    final dLon = _toRadians(lon2 - lon1);

    final y = math.sin(dLon) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);

    final initialBearingRad = math.atan2(y, x);
    final initialBearingDeg = (_toDegrees(initialBearingRad) + 360) % 360;
    return initialBearingDeg;
  }

  /// Convert numerical bearing degrees into nautical compass cardinal sectors.
  static String cardinalDirection(double bearingDegrees) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((bearingDegrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  static double _toDegrees(double radians) => radians * (180.0 / math.pi);
}
