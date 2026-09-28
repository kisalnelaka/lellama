import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/geo_math.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/ui/widgets/compass_badge.dart';

enum MapThemeMode {
  nauticalVoyager,
  tacticalNight,
  openStreet,
}

/// Production-grade maritime navigation map with interactive HUD,
/// multi-layer tile provider, boat telemetry, and swipeable PFZ hotspot cards.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  MapThemeMode _activeTheme = MapThemeMode.nauticalVoyager;
  int _selectedPFZIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _animatedMove(LatLng destLocation, double destZoom) {
    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  String _getTileUrl() {
    switch (_activeTheme) {
      case MapThemeMode.nauticalVoyager:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapThemeMode.tacticalNight:
        return 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case MapThemeMode.openStreet:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final boatPoint = LatLng(provider.boatLat, provider.boatLon);
    final pfzs = provider.pfzs;

    final markers = <Marker>[
      // 1. Boat Current GPS Location Marker with Pulse Radar Ring
      Marker(
        point: boatPoint,
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MarineColors.primaryBlue.withValues(alpha: 0.2),
                border: Border.all(
                  color: MarineColors.cyanAccent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: MarineColors.deepNavy,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_boat_filled_rounded,
                color: MarineColors.safetyYellow,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    ];

    // 2. Potential Fishing Zones Markers
    for (int i = 0; i < pfzs.length; i++) {
      final pfz = pfzs[i];
      final isSelected = i == _selectedPFZIndex;
      final pfzPoint = LatLng(pfz.latitude, pfz.longitude);
      final confColor = pfz.confidence >= 0.85
          ? MarineColors.safeGreen
          : (pfz.confidence >= 0.70
              ? MarineColors.safetyYellow
              : MarineColors.brightAmber);

      markers.add(
        Marker(
          point: pfzPoint,
          width: isSelected ? 56 : 46,
          height: isSelected ? 56 : 46,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedPFZIndex = i);
              _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              _animatedMove(pfzPoint, 10.0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: confColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.black87,
                  width: isSelected ? 3.5 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? confColor.withValues(alpha: 0.6)
                        : Colors.black38,
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 2 : 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.phishing_rounded,
                  color: isSelected ? Colors.white : Colors.black,
                  size: isSelected ? 28 : 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFE8F1F5), // Nautical sea-foam background for tile load
      child: Stack(
        children: [
          // Basemap & Markers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: boatPoint,
              initialZoom: 8.5,
              minZoom: 5.5,
              maxZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'lk.gov.fisheries.lellama',
                maxNativeZoom: 18,
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // 1. Top HUD: Telemetry & Sea State Strip
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _buildTopTelemetryHUD(context, provider),
          ),

          // 2. Right Vertical Map Control Toolbar
          Positioned(
            right: 12,
            top: 85,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: () {
                    final zoom = _mapController.camera.zoom + 1.0;
                    _animatedMove(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: () {
                    final zoom = _mapController.camera.zoom - 1.0;
                    _animatedMove(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Center Boat GPS',
                  iconColor: MarineColors.primaryBlue,
                  onTap: () => _animatedMove(boatPoint, 9.5),
                ),
                const SizedBox(height: 8),
                _buildMapThemeSwitcher(),
              ],
            ),
          ),

          // 3. Bottom PFZ Hotspots Carousel
          if (pfzs.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              height: 120,
              child: PageView.builder(
                controller: _pageController,
                itemCount: pfzs.length,
                onPageChanged: (index) {
                  setState(() => _selectedPFZIndex = index);
                  final target = pfzs[index];
                  _animatedMove(LatLng(target.latitude, target.longitude), 10.0);
                },
                itemBuilder: (ctx, idx) {
                  final targetPFZ = pfzs[idx];
                  final isSelected = idx == _selectedPFZIndex;
                  return _buildPFZCard(context, targetPFZ, provider, idx + 1, isSelected);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopTelemetryHUD(BuildContext context, MarineProvider provider) {
    final wave = provider.maxForecastedWaveHeight;
    final isRough = wave >= MarineConfig.waveWarningThreshold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MarineColors.deepNavy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Boat GPS Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      color: MarineColors.cyanAccent,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${provider.boatLat.toStringAsFixed(3)}°N, ${provider.boatLon.toStringAsFixed(3)}°E',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Mirissa Port • Departure Zone',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Sea State Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isRough
                  ? MarineColors.dangerRed.withValues(alpha: 0.25)
                  : MarineColors.safeGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRough ? MarineColors.dangerRed : MarineColors.safeGreen,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.waves_rounded,
                  size: 14,
                  color: isRough ? MarineColors.dangerRed : MarineColors.emeraldGreen,
                ),
                const SizedBox(width: 5),
                Text(
                  '${wave.toStringAsFixed(1)}m ${isRough ? "Rough" : "Calm"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isRough ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: iconColor ?? MarineColors.deepNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildMapThemeSwitcher() {
    return PopupMenuButton<MapThemeMode>(
      tooltip: 'Map Layer Style',
      offset: const Offset(-50, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (mode) => setState(() => _activeTheme = mode),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: MapThemeMode.nauticalVoyager,
          child: Row(
            children: [
              Icon(Icons.sailing_rounded, size: 20, color: MarineColors.primaryBlue),
              SizedBox(width: 10),
              Text('Maritime Chart (Voyager)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: MapThemeMode.tacticalNight,
          child: Row(
            children: [
              Icon(Icons.dark_mode_rounded, size: 20, color: Colors.indigo),
              SizedBox(width: 10),
              Text('Night Tactical Dark'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: MapThemeMode.openStreet,
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 20, color: Colors.green),
              SizedBox(width: 10),
              Text('Standard Coastal (OSM)'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.layers_rounded,
          size: 22,
          color: MarineColors.deepNavy,
        ),
      ),
    );
  }

  Widget _buildPFZCard(
    BuildContext context,
    PFZModel pfz,
    MarineProvider provider,
    int indexNumber,
    bool isSelected,
  ) {
    final distanceNM = GeoMath.distanceInNauticalMiles(
      provider.boatLat,
      provider.boatLon,
      pfz.latitude,
      pfz.longitude,
    );
    final bearingDeg = GeoMath.calculateBearing(
      provider.boatLat,
      provider.boatLon,
      pfz.latitude,
      pfz.longitude,
    );

    final confPercent = (pfz.confidence * 100).toInt();
    final confColor = pfz.confidence >= 0.85
        ? MarineColors.safeGreen
        : (pfz.confidence >= 0.70
            ? MarineColors.safetyYellow
            : MarineColors.brightAmber);

    return GestureDetector(
      onTap: () => _showPFZDetailsSheet(context, pfz, provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? MarineColors.deepNavy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MarineColors.cyanAccent
                : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? MarineColors.deepNavy.withValues(alpha: 0.35)
                  : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Compass & Zone Number
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: confColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: confColor, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: bearingDeg * (math.pi / 180.0),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: MarineColors.deepNavy,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Text(
                      '#$indexNumber',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Middle: Telemetry info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        'Zone $indexNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : MarineColors.deepNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: confColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$confPercent% Match',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: confColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${distanceNM.toStringAsFixed(1)} NM • ${bearingDeg.toStringAsFixed(0)}° Bearing',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? MarineColors.cyanAccent
                          : MarineColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SST: ${pfz.sstCelsius.toStringAsFixed(1)}°C • Chl: ${pfz.chlorophyll.toStringAsFixed(1)} mg',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Navigation Action Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isSelected ? MarineColors.cyanAccent : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  void _showPFZDetailsSheet(
    BuildContext context,
    PFZModel pfz,
    MarineProvider provider,
  ) {
    final distanceNM = GeoMath.distanceInNauticalMiles(
      provider.boatLat,
      provider.boatLon,
      pfz.latitude,
      pfz.longitude,
    );
    final bearingDeg = GeoMath.calculateBearing(
      provider.boatLat,
      provider.boatLon,
      pfz.latitude,
      pfz.longitude,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.tr('pfz_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: MarineColors.deepNavy,
                        ),
                      ),
                      Text(
                        'Satellite Source: Copernicus CMEMS L4',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  CompassBadge(
                    distanceNM: distanceNM,
                    bearingDegrees: bearingDeg,
                  ),
                ],
              ),
              const Divider(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _detailMetric(
                    label: provider.tr('confidence'),
                    value: '${(pfz.confidence * 100).toInt()}%',
                    icon: Icons.verified_rounded,
                    color: MarineColors.safeGreen,
                  ),
                  _detailMetric(
                    label: provider.tr('sst'),
                    value: '${pfz.sstCelsius.toStringAsFixed(1)}°C',
                    icon: Icons.thermostat_rounded,
                    color: MarineColors.primaryBlue,
                  ),
                  _detailMetric(
                    label: 'Chlorophyll-a',
                    value: '${pfz.chlorophyll.toStringAsFixed(1)} mg',
                    icon: Icons.water_drop_rounded,
                    color: Colors.teal.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 20, color: MarineColors.deepNavy),
                    const SizedBox(width: 8),
                    Text(
                      'GPS: ${pfz.latitude.toStringAsFixed(4)}°N, ${pfz.longitude.toStringAsFixed(4)}°E',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MarineColors.deepNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
