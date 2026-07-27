import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:rallymate/core/providers.dart';
import 'package:rallymate/core/theme.dart';
import 'package:rallymate/data/db/database.dart';
import 'package:rallymate/data/repositories/health_repository.dart';
import 'package:rallymate/domain/health_provider.dart';
import 'package:rallymate/features/devices/health_provider_setup_screen.dart';
import 'package:rallymate/services/ble_heart_rate.dart';
import 'package:rallymate/services/health_provider_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BleHeartRateDevice', () {
    test('normalizes empty names and invalid signal values', () {
      final device = BleHeartRateDevice.fromMap(const {
        'identifier': ' sensor-1 ',
        'name': ' \n\t ',
        'signal': -200,
      });

      expect(device.identifier, 'sensor-1');
      expect(device.name, 'Sensore cardiaco');
      expect(device.signal, -127);
    });

    test('sanitizes and limits peripheral names', () {
      final device = BleHeartRateDevice.fromMap({
        'identifier': 'sensor-2',
        'name': 'Polar\u0000   ${'H'.padRight(100, 'H')}',
        'signal': -48,
      });

      expect(device.name, isNot(contains('\u0000')));
      expect(device.name.length, lessThanOrEqualTo(80));
      expect(device.signal, -48);
    });

    test('accepts native id, localName and rssi aliases', () {
      final device = BleHeartRateDevice.fromMap(const {
        'id': 'sensor-alias',
        'localName': 'Garmin HRM',
        'rssi': '-61',
      });

      expect(device.identifier, 'sensor-alias');
      expect(device.name, 'Garmin HRM');
      expect(device.signal, -61);
    });
  });

  test(
    'scan accepts platform maps, removes invalid rows and deduplicates',
    () async {
      const channel = MethodChannel('com.rallymate/ble_heart_rate');
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final service = BleHeartRateService(HealthDataRepository(db));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'scan') return null;
            return <Object?>[
              <String, Object?>{
                'identifier': 'sensor-1',
                'name': '',
                'signal': -72,
              },
              <Object?, Object?>{
                'id': 'sensor-1',
                'localName': 'Polar H10',
                'rssi': -44,
              },
              <String, Object?>{
                'identifier': 'sensor-2',
                'name': 'Garmin HRM',
                'signal': -60,
              },
              <String, Object?>{'name': 'Senza identificativo'},
              'record-malformato',
            ];
          });

      final devices = await service.scan();

      expect(devices, hasLength(2));
      expect(devices.first.identifier, 'sensor-1');
      expect(devices.first.name, 'Polar H10');
      expect(devices.first.signal, -44);
      expect(devices.last.identifier, 'sensor-2');

      service.dispose();
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  test('native disconnected status clears stale persisted BLE state', () async {
    const channel = MethodChannel('com.rallymate/ble_heart_rate');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = HealthDataRepository(db);
    final service = BleHeartRateService(repository);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      service.dispose();
      await db.close();
    });
    await repository.saveBleSensor(
      localIdentifier: 'runtime-only-identifier',
      displayName: 'Polar H10',
      manufacturer: '',
      connected: true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'status') return null;
          return <String, Object?>{
            'supported': true,
            'bluetoothEnabled': true,
            'permissionsGranted': true,
            'connected': false,
          };
        });

    final status = await service.currentStatus();
    final sensor = await db.select(db.bleSensorDevices).getSingle();

    expect(status.connected, isFalse);
    expect(sensor.isConnected, isFalse);
  });

  testWidgets('sensor result stays visible and tappable on narrow screens', (
    tester,
  ) async {
    var connectCount = 0;
    const device = BleHeartRateDevice(
      identifier: 'AA:BB:CC:DD:EE:FF',
      name: 'Sensore cardiaco Bluetooth con un nome particolarmente lungo',
      signal: -54,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: rallyTheme(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 230,
                child: BleHeartRateDeviceTile(
                  device: device,
                  onSelect: () => connectCount++,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Sensore cardiaco Bluetooth'), findsOneWidget);
    expect(find.text('Segnale ottimo'), findsOneWidget);
    expect(find.text('Tocca per selezionare'), findsOneWidget);

    await tester.tap(find.byType(BleHeartRateDeviceTile));
    await tester.pump();

    expect(connectCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anonymous sensor always renders a visible connect action', (
    tester,
  ) async {
    const device = BleHeartRateDevice(
      identifier: 'anonymous-sensor',
      name: 'Sensore cardiaco',
      signal: -127,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: rallyTheme(),
        home: Scaffold(
          body: BleHeartRateDeviceTile(device: device, onSelect: () {}),
        ),
      ),
    );

    expect(find.text('Sensore cardiaco'), findsOneWidget);
    expect(find.text('Avvicina il sensore'), findsOneWidget);
    expect(find.text('Tocca per selezionare'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('temporarily disabled sensor result never renders as blank', (
    tester,
  ) async {
    const device = BleHeartRateDevice(
      identifier: 'waiting-sensor',
      name: 'Polar H10',
      signal: -45,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: rallyTheme(),
        home: const Scaffold(
          body: BleHeartRateDeviceTile(device: device, onSelect: null),
        ),
      ),
    );

    expect(find.text('Polar H10'), findsOneWidget);
    expect(find.text('Segnale ottimo'), findsOneWidget);
    expect(find.text('Sensore disponibile'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected sensor cannot be selected twice', (tester) async {
    var connectCount = 0;
    const device = BleHeartRateDevice(
      identifier: 'sensor-3',
      name: 'Polar H10',
      signal: -42,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: rallyTheme(),
        home: Scaffold(
          body: BleHeartRateDeviceTile(
            device: device,
            isConnected: true,
            onSelect: () => connectCount++,
          ),
        ),
      ),
    );

    expect(find.text('Sensore collegato'), findsOneWidget);
    await tester.tap(find.byType(BleHeartRateDeviceTile));
    expect(connectCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected sensor has an explicit visible state', (tester) async {
    const device = BleHeartRateDevice(
      identifier: 'sensor-selected',
      name: 'Polar H10',
      signal: -48,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: rallyTheme(),
        home: Scaffold(
          body: BleHeartRateDeviceTile(
            device: device,
            isSelected: true,
            onSelect: () {},
          ),
        ),
      ),
    );

    expect(find.text('Polar H10'), findsOneWidget);
    expect(find.text('Selezionato'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single anonymous scan result can be selected and connected end to end',
    (tester) async {
      const channel = MethodChannel('com.rallymate/ble_heart_rate');
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await db.close();
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'status':
              case 'requestPermissions':
                return <String, Object?>{
                  'supported': true,
                  'bluetoothEnabled': true,
                  'permissionsGranted': true,
                  'connected': false,
                };
              case 'scan':
                return <Object?>[
                  <String, Object?>{
                    'identifier': 'anonymous-sensor',
                    'name': '',
                    'signal': -52,
                  },
                ];
              case 'connect':
                return true;
              default:
                return null;
            }
          });

      final catalog = HealthProviderCatalog(
        updatedAt: DateTime(2026, 7, 15),
        providers: [
          HealthProviderDescriptor(
            id: 'BLE_HEART_RATE',
            displayName: 'Sensore cardiaco Bluetooth',
            description: 'Frequenza cardiaca live dal sensore.',
            category: HealthProviderCategory.liveSensor,
            connectionType: HealthConnectionType.bluetoothHeartRate,
            support: HealthProviderSupportStatus.production,
            rollout: HealthRolloutState.production,
            phonePlatforms: const {'android', 'ios'},
            capabilities: const HealthProviderCapabilities(
              metrics: {HealthMetricType.heartRate},
              supportsHeartRate: true,
              supportsLiveHeartRate: true,
              supportsDirectPairing: true,
            ),
            sourceUrl: Uri.parse(
              'https://www.bluetooth.com/specifications/specs/'
              'heart-rate-service-1-0/',
            ),
            artworkAsset: '',
            limitations: const [],
            requiresPremium: false,
            featureFlag: 'health_ble_hr',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            healthProviderCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: rallyTheme(),
            home: const HealthProviderSetupScreen(providerId: 'BLE_HEART_RATE'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerca sensori cardiaci'));
      await tester.pumpAndSettle();

      expect(find.text('Sensore cardiaco'), findsOneWidget);
      expect(find.text('Collega sensore'), findsNWidgets(2));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Collega sensore'),
            )
            .onPressed,
        isNotNull,
      );

      final deviceTile = find.byKey(
        const ValueKey('ble-device-anonymous-sensor'),
      );
      await tester.ensureVisible(deviceTile);
      await tester.pumpAndSettle();
      await tester.tap(deviceTile);
      await tester.pumpAndSettle();

      expect(find.text('Sensore collegato'), findsWidgets);
      expect(
        find.textContaining('In attesa del primo battito'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
