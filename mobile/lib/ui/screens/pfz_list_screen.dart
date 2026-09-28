import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/geo_math.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';

enum PFZSortOrder { nearest, confidence }

/// High-contrast tactical directory of all active Potential Fishing Zones.
class PFZListScreen extends StatefulWidget {
  const PFZListScreen({super.key});

  @override
  State<PFZListScreen> createState() => _PFZListScreenState();
}

class _PFZListScreenState extends State<PFZListScreen> {
  PFZSortOrder _sortOrder = PFZSortOrder.nearest;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final rawZones = provider.pfzs;

    // Create sorted list with distance & bearing pre-calculated
    final zoneItems = rawZones.map((pfz) {
      final dist = GeoMath.distanceInNauticalMiles(
        provider.boatLat,
        provider.boatLon,
        pfz.latitude,
        pfz.longitude,
      );
      final bearing = GeoMath.calculateBearing(
        provider.boatLat,
        provider.boatLon,
        pfz.latitude,
        pfz.longitude,
      );
      return _PFZItem(pfz: pfz, distanceNM: dist, bearingDeg: bearing);
    }).toList();

    if (_sortOrder == PFZSortOrder.nearest) {
      zoneItems.sort((a, b) => a.distanceNM.compareTo(b.distanceNM));
    } else {
      zoneItems.sort((a, b) => b.pfz.confidence.compareTo(a.pfz.confidence));
    }

    return Scaffold(
      backgroundColor: MarineColors.daylightSurface,
      body: Column(
        children: [
          // 1. Directory Header with Sort Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.selectedLanguage == 'si'
                            ? 'සක්‍රිය මත්ස්‍ය කලාප (${zoneItems.length})'
                            : (provider.selectedLanguage == 'ta'
                                ? 'செயலில் உள்ள மண்டலங்கள் (${zoneItems.length})'
                                : 'Active Fishing Zones (${zoneItems.length})'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: MarineColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Copernicus CMEMS • Sri Lanka EEZ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Toggle
                SegmentedButton<PFZSortOrder>(
                  segments: const [
                    ButtonSegment(
                      value: PFZSortOrder.nearest,
                      icon: Icon(Icons.near_me_outlined, size: 16),
                      label: Text('Nearest', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: PFZSortOrder.confidence,
                      icon: Icon(Icons.verified_outlined, size: 16),
                      label: Text('Score', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_sortOrder},
                  onSelectionChanged: (set) {
                    setState(() => _sortOrder = set.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return MarineColors.deepNavy;
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.black87;
                    }),
                  ),
                ),
              ],
            ),
          ),

          // 2. Zone Cards List
          Expanded(
            child: zoneItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 64,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.tr('no_alerts'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Sync" in top bar to refresh satellite data',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: zoneItems.length,
                    itemBuilder: (ctx, index) {
                      final item = zoneItems[index];
                      return _buildPFZCard(context, item, index + 1, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPFZCard(
    BuildContext context,
    _PFZItem item,
    int rank,
    MarineProvider provider,
  ) {
    final pfz = item.pfz;
    final confPercent = (pfz.confidence * 100).toInt();
    final confColor = pfz.confidence >= 0.85
        ? MarineColors.safeGreen
        : (pfz.confidence >= 0.70
            ? MarineColors.safetyYellow
            : MarineColors.brightAmber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Zone Rank, Confidence Badge, Compass Bearing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: MarineColors.deepNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ZONE #$rank',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: confColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: confColor, width: 1.2),
                      ),
                      child: Text(
                        '$confPercent% Confidence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: confColor == MarineColors.safetyYellow
                              ? const Color(0xFFB45309)
                              : confColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Compass Bearing Needle
                Row(
                  children: [
                    Transform.rotate(
                      angle: item.bearingDeg * (math.pi / 180.0),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: MarineColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.bearingDeg.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MarineColors.deepNavy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Distance Hero Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        item.distanceNM.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: MarineColors.deepNavy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'NM from current boat position',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Oceanographic Telemetry Grid
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryCell(
                    label: 'Sea Surface Temp',
                    value: '${pfz.sstCelsius.toStringAsFixed(1)}°C',
                    icon: Icons.thermostat_rounded,
                    color: MarineColors.primaryBlue,
                  ),
                ),
                Expanded(
                  child: _buildTelemetryCell(
                    label: 'Thermal Front',
                    value: '${pfz.sstGradient.toStringAsFixed(2)}°C/km',
                    icon: Icons.grain_rounded,
                    color: Colors.deepOrange,
                  ),
                ),
                Expanded(
                  child: _buildTelemetryCell(
                    label: 'Chlorophyll-a',
                    value: '${pfz.chlorophyll.toStringAsFixed(1)} mg',
                    icon: Icons.water_drop_rounded,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // GPS Coordinates footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Target Coordinates: ${pfz.latitude.toStringAsFixed(4)}°N, ${pfz.longitude.toStringAsFixed(4)}°E',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCell({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: MarineColors.deepNavy,
          ),
        ),
      ],
    );
  }
}

class _PFZItem {
  final PFZModel pfz;
  final double distanceNM;
  final double bearingDeg;

  _PFZItem({
    required this.pfz,
    required this.distanceNM,
    required this.bearingDeg,
  });
}
