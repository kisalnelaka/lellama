import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';
import 'package:lellama_mobile/ui/widgets/hazard_banner.dart';
import 'package:lellama_mobile/ui/screens/map_screen.dart';
import 'package:lellama_mobile/ui/screens/pfz_list_screen.dart';
import 'package:lellama_mobile/ui/screens/weather_screen.dart';

/// Modern offshore marine dashboard with bottom navigation,
/// compact app bar telemetry, and full-screen view allocation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapScreen(),
    PFZListScreen(),
    WeatherScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final activePFZCount = provider.pfzs.length;

    return Scaffold(
      backgroundColor: MarineColors.daylightSurface,
      appBar: AppBar(
        backgroundColor: MarineColors.deepNavy,
        elevation: 0,
        titleSpacing: 14,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: MarineColors.oceanNavy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MarineColors.cyanAccent.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.anchor_rounded,
                color: MarineColors.safetyYellow,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    MarineConfig.appTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    provider.selectedLanguage == 'si'
                        ? 'සාගර PFZ බුද්ධි පද්ධතිය'
                        : (provider.selectedLanguage == 'ta'
                            ? 'கடல் தகவல் தளம்'
                            : 'Marine Tech Platform'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
        actions: [
          // 1. Connectivity Status Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: provider.isOffline
                    ? MarineColors.safetyYellow.withValues(alpha: 0.6)
                    : MarineColors.safeGreen.withValues(alpha: 0.6),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.isOffline
                        ? MarineColors.safetyYellow
                        : MarineColors.safeGreen,
                    boxShadow: [
                      BoxShadow(
                        color: provider.isOffline
                            ? MarineColors.safetyYellow
                            : MarineColors.safeGreen,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  provider.isOffline ? 'CACHED' : 'ONLINE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: provider.isOffline
                        ? MarineColors.safetyYellow
                        : Colors.greenAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 2. Language Selector Dropdown
          PopupMenuButton<String>(
            tooltip: 'Change Language / භාෂාව',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (code) => provider.setLanguage(code),
            itemBuilder: (ctx) => [
              _buildLangMenuItem('si', 'සිංහල (Sinhala)', provider.selectedLanguage == 'si'),
              _buildLangMenuItem('ta', 'தமிழ் (Tamil)', provider.selectedLanguage == 'ta'),
              _buildLangMenuItem('en', 'English', provider.selectedLanguage == 'en'),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.selectedLanguage == 'si'
                        ? 'සිං'
                        : (provider.selectedLanguage == 'ta' ? 'த' : 'EN'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Quick Sync Button
          IconButton(
            tooltip: provider.tr('sync_now'),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: MarineColors.safetyYellow,
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    color: MarineColors.safetyYellow,
                    size: 24,
                  ),
            onPressed: provider.isLoading ? null : () => provider.syncData(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Severe Hazard Warning Banner (Only visible during rough sea/squalls)
            if (provider.hasActiveWeatherHazard) const HazardBanner(),

            // Primary Screen Content (Full viewport)
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: MarineColors.oceanNavy,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined, color: Colors.black87),
            selectedIcon: const Icon(Icons.map_rounded, color: MarineColors.safetyYellow),
            label: provider.selectedLanguage == 'si'
                ? 'සිතියම'
                : (provider.selectedLanguage == 'ta' ? 'வரைபடம்' : 'Map View'),
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$activePFZCount'),
              backgroundColor: MarineColors.primaryBlue,
              isLabelVisible: activePFZCount > 0,
              child: const Icon(Icons.radar_outlined, color: Colors.black87),
            ),
            selectedIcon: Badge(
              label: Text('$activePFZCount'),
              backgroundColor: MarineColors.cyanAccent,
              textColor: Colors.black,
              isLabelVisible: activePFZCount > 0,
              child: const Icon(Icons.radar_rounded, color: MarineColors.safetyYellow),
            ),
            label: provider.selectedLanguage == 'si'
                ? 'කලාප ($activePFZCount)'
                : (provider.selectedLanguage == 'ta'
                    ? 'மண்டலங்கள்'
                    : 'PFZ Zones'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.water_outlined, color: Colors.black87),
            selectedIcon: const Icon(Icons.waves_rounded, color: MarineColors.safetyYellow),
            label: provider.selectedLanguage == 'si'
                ? 'කාලගුණය'
                : (provider.selectedLanguage == 'ta' ? 'வானிலை' : 'Weather'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildLangMenuItem(String code, String title, bool isSelected) {
    return PopupMenuItem(
      value: code,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              color: isSelected ? MarineColors.primaryBlue : Colors.black87,
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, color: MarineColors.primaryBlue, size: 18),
        ],
      ),
    );
  }
}
