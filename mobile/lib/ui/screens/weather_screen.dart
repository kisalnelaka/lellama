import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/data/models/weather_model.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';

/// State-of-the-art hourly marine weather forecast console
/// displaying ocean swell dynamics, current vectors, and squall advisories.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String _selectedHarbourFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final allForecasts = provider.weatherForecasts;
    final alerts = provider.alerts;

    // Filter forecasts by harbour if selected
    final filteredForecasts = _selectedHarbourFilter == 'All'
        ? allForecasts
        : allForecasts
            .filter((f) => f.locationName.toLowerCase().contains(_selectedHarbourFilter.toLowerCase()))
            .toList();

    final maxWave = provider.maxForecastedWaveHeight;
    final isDangerous = maxWave >= MarineConfig.waveWarningThreshold;

    return Scaffold(
      backgroundColor: MarineColors.daylightSurface,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // 1. Severe Weather Alerts Banner (If active)
          if (alerts.isNotEmpty) ...[
            for (final alert in alerts)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: MarineColors.dangerRed, width: 2.0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MarineColors.dangerRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: MarineColors.dangerRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.alertLevel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: MarineColors.dangerRed,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            alert.getLocalizedMessage(provider.selectedLanguage),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // 2. Hero Sea State Ocean Telemetry Card
          _buildHeroSeaStateCard(context, provider, maxWave, isDangerous),
          const SizedBox(height: 18),

          // 3. Location / Harbour Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'All Ports / මුළු දිවයිනම'),
                const SizedBox(width: 8),
                _buildFilterChip('Mirissa', 'Mirissa (දකුණ)'),
                const SizedBox(width: 8),
                _buildFilterChip('Beruwala', 'Beruwala (බස්නාහිර)'),
                const SizedBox(width: 8),
                _buildFilterChip('Galle', 'Galle (ගාල්ල)'),
                const SizedBox(width: 8),
                _buildFilterChip('Trinco', 'Trincomalee (නැගෙනහිර)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                provider.selectedLanguage == 'si'
                    ? 'පැය 24 සාගර කාලගුණ අනාවැකිය'
                    : (provider.selectedLanguage == 'ta'
                        ? '24 மணி நேர கடல் முன்னறிவிப்பு'
                        : '24-Hour Marine Forecast'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: MarineColors.deepNavy,
                ),
              ),
              Text(
                '${filteredForecasts.length} Hours',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MarineColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5. Forecast Cards List
          if (filteredForecasts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_sync_outlined, size: 48, color: Colors.black38),
                  const SizedBox(height: 12),
                  Text(
                    provider.selectedLanguage == 'si'
                        ? 'දත්ත යාවත්කාලීන කිරීමට "Sync" තට්ටු කරන්න.'
                        : 'Tap "Sync" to update offshore forecasts.',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            for (final f in filteredForecasts) ...[
              _buildForecastItem(context, f, provider),
            ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroSeaStateCard(
    BuildContext context,
    MarineProvider provider,
    double maxWave,
    bool isDangerous,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDangerous
              ? [const Color(0xFF991B1B), const Color(0xFFDC2626)]
              : [MarineColors.deepNavy, const Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tsunami_rounded, color: MarineColors.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    provider.selectedLanguage == 'si'
                        ? 'වත්මන් මුහුදු තත්ත්වය'
                        : (provider.selectedLanguage == 'ta' ? 'கடல் நிலை' : 'CURRENT SEA STATE'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDangerous
                      ? Colors.red.shade900
                      : MarineColors.safeGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDangerous ? Colors.white70 : Colors.greenAccent,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  isDangerous ? 'ROUGH SEA' : 'NORMAL / CALM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isDangerous ? Colors.white : Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                maxWave.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'meters (Wave Height)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricSubItem(
                label: 'Swell Waves',
                value: '${(maxWave * 0.7).toStringAsFixed(1)} m',
                icon: Icons.water_rounded,
              ),
              _buildMetricSubItem(
                label: 'Wind Waves',
                value: '${(maxWave * 0.6).toStringAsFixed(1)} m',
                icon: Icons.air_rounded,
              ),
              _buildMetricSubItem(
                label: 'Ocean Current',
                value: '0.8 kts',
                icon: Icons.navigation_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSubItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: MarineColors.cyanAccent, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedHarbourFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedHarbourFilter = key);
      },
      selectedColor: MarineColors.oceanNavy,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? MarineColors.oceanNavy : const Color(0xFFCBD5E1),
        width: 1.2,
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildForecastItem(
    BuildContext context,
    WeatherModel forecast,
    MarineProvider provider,
  ) {
    final wave = forecast.waveHeight;
    final isRough = wave >= MarineConfig.waveWarningThreshold;

    String timeFormatted = forecast.validForTime;
    if (timeFormatted.contains('T')) {
      final parts = timeFormatted.split('T');
      if (parts.length > 1 && parts[1].length >= 5) {
        timeFormatted = parts[1].substring(0, 5);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRough ? MarineColors.dangerRed : const Color(0xFFE2E8F0),
          width: isRough ? 1.8 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isRough ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRough ? MarineColors.dangerRed : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              timeFormatted,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isRough ? MarineColors.dangerRed : MarineColors.deepNavy,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Location & details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast.locationName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Swell: ${forecast.swellWaveHeight.toStringAsFixed(1)}m • Current: ${(forecast.oceanCurrentVelocity * 1.94384).toStringAsFixed(1)} kts',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Wave height gauge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${wave.toStringAsFixed(1)} m',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isRough ? MarineColors.dangerRed : MarineColors.safeGreen,
                ),
              ),
              Text(
                isRough ? 'WARNING' : 'SAFE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isRough ? MarineColors.dangerRed : MarineColors.safeGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _IterableFilter<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) => where(test);
}
