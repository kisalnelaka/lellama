import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lellama_mobile/main.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/core/geo_math.dart';
import 'package:lellama_mobile/data/models/pfz_model.dart';
import 'package:lellama_mobile/data/models/weather_model.dart';
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
}

