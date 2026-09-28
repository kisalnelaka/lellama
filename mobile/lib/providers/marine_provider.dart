import 'package:flutter/foundation.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/localization.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/data/models/weather_model.dart';
import 'package:lellama_mobile/data/models/alert_model.dart';
import 'package:lellama_mobile/services/sync_service.dart';

/// Central state management for the offline-first maritime mobile client.
class MarineProvider extends ChangeNotifier {
  final SyncService _syncService;

  MarineProvider({SyncService? syncService})
      : _syncService = syncService ?? SyncService() {
    _init();
  }

  // State fields
  List<PFZModel> _pfzs = [];
  List<WeatherModel> _weatherForecasts = [];
  List<AlertModel> _alerts = [];
  bool _isLoading = false;
  bool _isOffline = true;
  String _selectedLanguage = 'si'; // Default to Sinhala for Sri Lankan coastal fisheries
  String _lastSyncDisplay = 'Not Synced';

  // Boat GPS location (defaults to Southern departure point: Mirissa Harbour)
  double _boatLat = MarineConfig.defaultLat;
  double _boatLon = MarineConfig.defaultLon;

  // Getters
  List<PFZModel> get pfzs => _pfzs;
  List<WeatherModel> get weatherForecasts => _weatherForecasts;
  List<AlertModel> get alerts => _alerts;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get selectedLanguage => _selectedLanguage;
  String get lastSyncDisplay => _lastSyncDisplay;
  double get boatLat => _boatLat;
  double get boatLon => _boatLon;

  /// Returns true if dangerous marine wave height (>= 2.5m) is detected.
  bool get hasActiveWeatherHazard {
    if (_alerts.isNotEmpty) return true;
    for (final w in _weatherForecasts) {
      if (w.waveHeight >= MarineConfig.waveWarningThreshold) return true;
    }
    return false;
  }

  /// Get the maximum forecasted wave height in meters.
  double get maxForecastedWaveHeight {
    if (_weatherForecasts.isEmpty) return 1.8;
    double maxW = 0.0;
    for (final w in _weatherForecasts) {
      if (w.waveHeight > maxW) maxW = w.waveHeight;
    }
    return maxW;
  }

  String tr(String key) => MarineLocale.text(key, _selectedLanguage);

  Future<void> _init() async {
    try {
      final savedLang = await _syncService.dbHelper.getSetting('selected_language');
      if (savedLang != null) {
        _selectedLanguage = savedLang;
      }
      final savedSync = await _syncService.dbHelper.getSetting('last_sync_timestamp');
      if (savedSync != null) {
        final dt = DateTime.tryParse(savedSync);
        if (dt != null) {
          _lastSyncDisplay = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} (${dt.day}/${dt.month})';
        }
      }
    } catch (_) {}
    await syncData();
  }

  Future<void> syncData() async {
    _isLoading = true;
    notifyListeners();

    final result = await _syncService.synchronize();
    _pfzs = result.pfzs;
    _weatherForecasts = result.forecasts;
    _alerts = result.alerts;
    _isOffline = result.isOffline;
    _isLoading = false;

    final now = DateTime.now();
    _lastSyncDisplay = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (lang != _selectedLanguage) {
      _selectedLanguage = lang;
      notifyListeners();
      try {
        await _syncService.dbHelper.setSetting('selected_language', lang);
      } catch (_) {}
    }
  }

  void updateBoatLocation(double lat, double lon) {
    _boatLat = lat;
    _boatLon = lon;
    notifyListeners();
  }
}
