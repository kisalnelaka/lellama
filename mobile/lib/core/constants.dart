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

  // Tile Providers
  static const String tileProviderCartoVoyager =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
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
}

