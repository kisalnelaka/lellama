import 'package:flutter/material.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/geo_math.dart';

/// High-contrast tactile badge showing compass bearing, cardinal sector, and distance in Nautical Miles.
class CompassBadge extends StatelessWidget {
  final double distanceNM;
  final double bearingDegrees;

  const CompassBadge({
    super.key,
    required this.distanceNM,
    required this.bearingDegrees,
  });

  @override
  Widget build(BuildContext context) {
    final cardinal = GeoMath.cardinalDirection(bearingDegrees);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MarineColors.oceanNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: (bearingDegrees * 3.14159 / 180.0),
                child: const Icon(
                  Icons.navigation,
                  color: MarineColors.safetyYellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${bearingDegrees.toStringAsFixed(0)}° $cardinal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${distanceNM.toStringAsFixed(1)} NM',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: MarineColors.safetyYellow,
            ),
          ),
        ],
      ),
    );
  }
}
