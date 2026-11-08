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

  // Boat GPS location & departure harbour
  double _boatLat = MarineConfig.defaultLat;
  double _boatLon = MarineConfig.defaultLon;
  String _departureHarborName = 'Mirissa Fishery Harbour';
  String _vesselRegistration = '';
  int? _activeWaypointIndex;

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
  String get departureHarborName => _departureHarborName;
  String get vesselRegistration => _vesselRegistration;
  int? get activeWaypointIndex => _activeWaypointIndex;

  PFZModel? get activeWaypoint {
    if (_activeWaypointIndex == null ||
        _activeWaypointIndex! < 0 ||
        _activeWaypointIndex! >= _pfzs.length) {
      return null;
    }
    return _pfzs[_activeWaypointIndex!];
  }

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
      final savedHarbor = await _syncService.dbHelper.getSetting('departure_harbor_name');
      if (savedHarbor != null) {
        _departureHarborName = savedHarbor;
      }
      final savedLat = await _syncService.dbHelper.getSetting('boat_lat');
      final savedLon = await _syncService.dbHelper.getSetting('boat_lon');
      if (savedLat != null && savedLon != null) {
        final lat = double.tryParse(savedLat);
        final lon = double.tryParse(savedLon);
        if (lat != null && lon != null) {
          _boatLat = lat;
          _boatLon = lon;
        }
      }
      final savedVessel = await _syncService.dbHelper.getSetting('vessel_registration');
      if (savedVessel != null) {
        _vesselRegistration = savedVessel;
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

    final result = await _syncService.synchronize(
      vesselId: _vesselRegistration.isNotEmpty ? _vesselRegistration : null,
    );
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

  Future<void> setDepartureHarbor(HarborLocation harbor) async {
    _departureHarborName = harbor.name;
    _boatLat = harbor.latitude;
    _boatLon = harbor.longitude;
    notifyListeners();
    try {
      await _syncService.dbHelper.setSetting('departure_harbor_name', harbor.name);
      await _syncService.dbHelper.setSetting('boat_lat', harbor.latitude.toString());
      await _syncService.dbHelper.setSetting('boat_lon', harbor.longitude.toString());
    } catch (_) {}
  }

  Future<void> setVesselRegistration(String registration) async {
    _vesselRegistration = registration.trim().toUpperCase();
    notifyListeners();
    try {
      await _syncService.dbHelper.setSetting('vessel_registration', _vesselRegistration);
    } catch (_) {}
  }

  void setActiveWaypoint(int? index) {
    if (index == null || index < 0 || index >= _pfzs.length) {
      _activeWaypointIndex = null;
    } else {
      _activeWaypointIndex = index;
    }
    notifyListeners();
  }

  void updateBoatLocation(double lat, double lon) {
    setBoatLocation(lat, lon);
  }

  Future<void> setBoatLocation(double lat, double lon) async {
    _boatLat = lat;
    _boatLon = lon;
    notifyListeners();
    try {
      await _syncService.dbHelper.setSetting('boat_lat', lat.toString());
      await _syncService.dbHelper.setSetting('boat_lon', lon.toString());
    } catch (_) {}
  }
}
