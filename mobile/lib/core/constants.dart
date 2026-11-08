import 'package:flutter/material.dart';

/// Design tokens optimized for extreme equatorial sunlight legibility and high-contrast night vision.
class MarineColors {
  // Modern Deep Maritime Palette
  static const Color deepNavy = Color(0xFF0A192F);
  static const Color oceanNavy = Color(0xFF0F2744);
  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color coralRed = Color(0xFFEF4444);

  // High-Contrast Safety Tokens
  static const Color safetyYellow = Color(0xFFFFD700);
  static const Color brightAmber = Color(0xFFFF9800);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color safeGreen = Color(0xFF16A34A);

  // Clean Light Surfaces
  static const Color daylightSurface = Color(0xFFF8FAFC);
  static const Color daylightCard = Color(0xFFFFFFFF);
  static const Color highContrastBorder = Color(0xFFCBD5E1);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Night-vision tactical red mode
  static const Color nightSurface = Color(0xFF0B132B);
  static const Color nightCard = Color(0xFF1C2541);
  static const Color nightRedText = Color(0xFFFF5252);
}

class MarineConfig {
  static const String appTitle = 'LELLAMA • ලෙල්ලම';
  static const String appSubtitle = 'Marine Intelligence & Safety Platform';

  // Production VPS Backend
  static const String apiBaseUrl = 'https://lellama.loghorizon.online/api/v1';
  static const String apiLocalhostUrl = 'http://localhost:8000/api/v1';

  // Tile Providers (Public zero-watermark maritime basemaps)
  static const String tileProviderEsriTopo =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
  static const String tileProviderEsriSatellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String tileProviderEsriDark =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String tileProviderOSM =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Sri Lanka Geographic Bounds & Harbours
  static const double defaultLat = 5.9482; // Mirissa Fishery Harbour
  static const double defaultLon = 80.4578;
  static const double minLat = 4.5;
  static const double maxLat = 10.5;
  static const double minLon = 78.5;
  static const double maxLon = 83.5;

  // Maritime Safety Thresholds
  static const double waveWarningThreshold = 2.5; // meters
  static const double waveDangerThreshold = 3.5; // meters

  // Key Sri Lankan Departure Harbours
  static const List<HarborLocation> sriLankanHarbors = [
    HarborLocation(
      name: 'Mirissa Fishery Harbour',
      nameSinhala: 'මිරිස්ස ධීවර වරාය',
      nameTamil: 'மிரிஸ்ஸ மீன்பிடித் துறைமுகம்',
      latitude: 5.9482,
      longitude: 80.4578,
      region: 'Southern Province',
    ),
    HarborLocation(
      name: 'Beruwala Fishery Harbour',
      nameSinhala: 'බේරුවල ධීවර වරාය',
      nameTamil: 'பேருவளை மீன்பிடித் துறைமுகம்',
      latitude: 6.4789,
      longitude: 79.9827,
      region: 'Western Province',
    ),
    HarborLocation(
      name: 'Galle Fishery Harbour',
      nameSinhala: 'ගාල්ල ධීවර වරාය',
      nameTamil: 'காலி மீன்பிடித் துறைமுகம்',
      latitude: 6.0329,
      longitude: 80.2168,
      region: 'Southern Province',
    ),
    HarborLocation(
      name: 'Tangalle Fishery Harbour',
      nameSinhala: 'තංගල්ල ධීවර වරාය',
      nameTamil: 'தங்கல்ல மீன்பிடித் துறைமுகம்',
      latitude: 6.0244,
      longitude: 80.7941,
      region: 'Southern Province',
    ),
    HarborLocation(
      name: 'Dondra Fishery Point',
      nameSinhala: 'දෙවිනුවර ධීවර තොටුපළ',
      nameTamil: 'தேவிநுவர மீன்பிடித் தளம்',
      latitude: 5.9234,
      longitude: 80.5894,
      region: 'Southern Province',
    ),
    HarborLocation(
      name: 'Negombo Lagoon & Harbour',
      nameSinhala: 'මීගමුව ධීවර වරාය',
      nameTamil: 'நீர்கொழும்பு மீன்பிடித் துறைமுகம்',
      latitude: 7.2008,
      longitude: 79.8736,
      region: 'Western Province',
    ),
    HarborLocation(
      name: 'Trincomalee Cod Bay Harbour',
      nameSinhala: 'ත්‍රිකුණාමලය කොඩ් බේ වරාය',
      nameTamil: 'திருகோணமலை காட் விரிகுடா',
      latitude: 8.5874,
      longitude: 81.2152,
      region: 'Eastern Province',
    ),
    HarborLocation(
      name: 'Kalpitiya Landing Site',
      nameSinhala: 'කල්පිටිය ගොඩබෑමේ තොටුපළ',
      nameTamil: 'கற்பிட்டி இறங்கு தளம்',
      latitude: 8.2285,
      longitude: 79.7656,
      region: 'North Western Province',
    ),
  ];
}

/// Structured metadata for a Sri Lankan coastal departure harbour.
class HarborLocation {
  final String name;
  final String nameSinhala;
  final String nameTamil;
  final double latitude;
  final double longitude;
  final String region;

  const HarborLocation({
    required this.name,
    required this.nameSinhala,
    required this.nameTamil,
    required this.latitude,
    required this.longitude,
    required this.region,
  });

  String getLocalizedName(String lang) {
    if (lang == 'si') return nameSinhala;
    if (lang == 'ta') return nameTamil;
    return name;
  }
}


