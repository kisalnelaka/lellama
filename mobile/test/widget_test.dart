import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lellama_mobile/main.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/geo_math.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/data/models/weather_model.dart';
import 'package:lellama_mobile/data/models/alert_model.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';
import 'package:lellama_mobile/services/sync_service.dart';

class MockOfflineSyncService extends SyncService {
  @override
  Future<SyncResult> synchronize({
    String? token,
    String? vesselId,
    String baseUrl = MarineConfig.apiLocalhostUrl,
  }) async {
    return SyncResult(
      isSuccess: true,
      isOffline: true,
      message: 'Test offline sync',
      pfzs: [
        PFZModel(
          id: 'test-pfz-01',
          latitude: 5.82,
          longitude: 80.60,
          sstCelsius: 28.3,
          sstGradient: 0.35,
          chlorophyll: 2.2,
          confidence: 0.91,
          detectionDate: '2026-09-28',
        ),
      ],
      forecasts: [
        WeatherModel(
          id: 'test-w-01',
          latitude: 5.95,
          longitude: 80.45,
          locationName: 'Mirissa Harbour',
          validForTime: '12:00',
          waveHeight: 1.8,
          waveDirection: 210.0,
          windWaveHeight: 0.9,
          swellWaveHeight: 1.4,
          oceanCurrentVelocity: 0.5,
        ),
      ],
      alerts: [],
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Great-circle navigation distance and bearing calculation', () {
    // Mirissa Harbour to Dondra PFZ Point
    final distanceNM = GeoMath.distanceInNauticalMiles(5.9482, 80.4578, 5.7820, 80.5210);
    final bearingDeg = GeoMath.calculateBearing(5.9482, 80.4578, 5.7820, 80.5210);
    final cardinal = GeoMath.cardinalDirection(bearingDeg);

    expect(distanceNM, greaterThan(5.0));
    expect(distanceNM, lessThan(20.0));
    expect(bearingDeg, greaterThan(140.0));
    expect(bearingDeg, lessThan(180.0));
    expect(cardinal, equals('SSE'));
  });

  testWidgets('Lellama Marine App renders daylight UI and language controls', (WidgetTester tester) async {
    // Set viewport dimensions for mobile display test
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockSync = MockOfflineSyncService();
    final testProvider = MarineProvider(syncService: mockSync);
    await testProvider.syncData();

    await tester.pumpWidget(LellamaMarineApp(provider: testProvider));
    await tester.pumpAndSettle();

    // Verify Title and primary maritime actions
    expect(find.text(MarineConfig.appTitle), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

    // Open language menu and select English
    final langBtn = find.byType(PopupMenuButton<String>);
    expect(langBtn, findsOneWidget);
    await tester.tap(langBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('English'), findsOneWidget);
    await tester.tap(find.textContaining('English'));
    await tester.pumpAndSettle();

    expect(testProvider.selectedLanguage, equals('en'));

    // Verify English localized navigation bar destinations appear
    expect(find.text('Map View'), findsOneWidget);
    expect(find.text('PFZ Zones'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);

    // Tap PFZ Zones tab
    await tester.tap(find.text('PFZ Zones'));
    await tester.pumpAndSettle();

    // Verify Potential Fishing Zone cards render
    expect(find.byType(ListView), findsWidgets);
    expect(find.textContaining('Confidence'), findsWidgets);
  });

  test('PFZModel GeoJSON feature parsing and SQLite round-trip mapping', () {
    final feature = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [80.75, 5.85],
      },
      'properties': {
        'id': 'pfz-geo-test',
        'detection_date': '2026-09-29',
        'sst_celsius': 28.5,
        'sst_gradient_c_per_km': 0.42,
        'chlorophyll_mg_m3': 1.95,
        'confidence': 0.89,
        'status': 'active',
      },
    };

    final pfz = PFZModel.fromGeoJsonFeature(feature);
    expect(pfz.id, equals('pfz-geo-test'));
    expect(pfz.longitude, equals(80.75));
    expect(pfz.latitude, equals(5.85));
    expect(pfz.sstCelsius, equals(28.5));
    expect(pfz.sstGradient, equals(0.42));
    expect(pfz.chlorophyll, equals(1.95));
    expect(pfz.confidence, equals(0.89));

    final dbMap = pfz.toDbMap();
    final roundTripped = PFZModel.fromDbMap(dbMap);
    expect(roundTripped.id, equals(pfz.id));
    expect(roundTripped.latitude, equals(pfz.latitude));
    expect(roundTripped.longitude, equals(pfz.longitude));
    expect(roundTripped.confidence, equals(pfz.confidence));
  });

  test('WeatherModel and AlertModel localization and data contracts', () {
    final weather = WeatherModel(
      id: 'w-test-1',
      latitude: 6.03,
      longitude: 80.21,
      locationName: 'Galle Fishery Harbour',
      validForTime: '2026-09-29T06:00:00Z',
      waveHeight: 2.7,
      waveDirection: 215.0,
      windWaveHeight: 1.2,
      swellWaveHeight: 2.1,
      oceanCurrentVelocity: 0.7,
    );

    final wMap = weather.toDbMap();
    final wRestored = WeatherModel.fromDbMap(wMap);
    expect(wRestored.locationName, equals('Galle Fishery Harbour'));
    expect(wRestored.waveHeight, equals(2.7));

    final alert = AlertModel(
      id: 'alert-test-1',
      alertLevel: 'danger',
      messageSinhala: 'අවවාදයයි: මුහුද රළුයි',
      messageTamil: 'எச்சரிக்கை: கொந்தளிப்பான கடல்',
      messageEnglish: 'WARNING: Rough sea conditions',
      triggerCause: 'wave_height_exceeded',
      createdAt: '2026-09-29T04:00:00Z',
    );

    expect(alert.getLocalizedMessage('si'), contains('අවවාදයයි'));
    expect(alert.getLocalizedMessage('ta'), contains('எச்சரிக்கை'));
    expect(alert.getLocalizedMessage('en'), contains('WARNING'));
  });
}

