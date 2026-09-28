import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';

/// Ultra-high-contrast warning banner visible under blinding equatorial sunlight.
class HazardBanner extends StatelessWidget {
  const HazardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final hasHazard = provider.hasActiveWeatherHazard;
    final maxWave = provider.maxForecastedWaveHeight;
    final isDanger = maxWave >= MarineConfig.waveDangerThreshold;

    final bannerBg = isDanger ? MarineColors.dangerRed : MarineColors.safetyYellow;
    final textColor = isDanger ? Colors.white : Colors.black;
    final iconColor = isDanger ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasHazard ? bannerBg : const Color(0xFFE8F5E9),
        border: Border.all(
          color: hasHazard ? Colors.black : MarineColors.safeGreen,
          width: 3.0,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasHazard ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            size: 44,
            color: hasHazard ? iconColor : MarineColors.safeGreen,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasHazard
                      ? (isDanger ? provider.tr('danger') : provider.tr('warning'))
                      : provider.tr('safe'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: hasHazard ? textColor : MarineColors.safeGreen,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasHazard
                      ? '${provider.tr('wave_height')}: ${maxWave.toStringAsFixed(1)} ${provider.tr('meters')} | ${provider.tr('current')}: 0.8 ${provider.tr('knots')}'
                      : '${provider.tr('wave_height')}: 1.2 ${provider.tr('meters')} (Calm)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasHazard ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
