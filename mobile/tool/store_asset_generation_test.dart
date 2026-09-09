import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_screenshot_app.dart' as store;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() async {
    await _loadStoreAssetFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, (call) async {
          return switch (call.method) {
            'isDeviceSupported' => false,
            'canCheckBiometrics' => false,
            'getAvailableBiometrics' => <String>[],
            'authenticate' => false,
            'stopAuthentication' => true,
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          return switch (call.method) {
            'read' => null,
            'readAll' => <String, String>{},
            'write' => null,
            'delete' => null,
            'deleteAll' => null,
            'containsKey' => false,
            _ => null,
          };
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  const outputRoot = 'store_assets/actual/v1.0.36';
  const devices = <_StoreDevice>[
    _StoreDevice(
      name: 'Google Play phone',
      size: Size(1080, 1920),
      outputBase: 'play_store/phone',
    ),
    _StoreDevice(
      name: 'Google Play 7-inch tablet',
      size: Size(1200, 1920),
      outputBase: 'play_store/7_inch_tablet',
    ),
    _StoreDevice(
      name: 'Google Play 10-inch tablet',
      size: Size(1600, 2560),
      outputBase: 'play_store/10_inch_tablet',
    ),
    _StoreDevice(
      name: 'App Store iPhone 6.9-inch',
      size: Size(1320, 2868),
      outputBase: 'app_store/iphone_6_9',
    ),
    _StoreDevice(
      name: 'App Store iPad 13-inch',
      size: Size(2048, 2732),
      outputBase: 'app_store/ipad_13',
    ),
  ];

  const captures = <_StoreCapture>[
    _StoreCapture(scenario: 'splash', output: 'splash_login/splash.png'),
    _StoreCapture(scenario: 'login', output: 'splash_login/login.png'),
    _StoreCapture(
      scenario: 'seller_marketplace',
      output: 'screenshots/01_seller_marketplace.png',
    ),
    _StoreCapture(
      scenario: 'seller_discount_amount',
      output: 'screenshots/02_seller_discount_amount.png',
    ),
    _StoreCapture(
      scenario: 'active_orders',
      output: 'screenshots/03_active_orders.png',
    ),
    _StoreCapture(
      scenario: 'delivery_tracking',
      output: 'screenshots/04_delivery_tracking.png',
    ),
    _StoreCapture(
      scenario: 'secure_chat',
      output: 'screenshots/05_secure_chat.png',
    ),
  ];

  for (final device in devices) {
    group(device.name, () {
      for (final capture in captures) {
        testWidgets(capture.scenario, (tester) async {
          final goldenPath =
              '$outputRoot/${device.outputBase}/${capture.output}';
          Directory(goldenPath).parent.createSync(recursive: true);

          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = device.size;
          addTearDown(() {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPhysicalSize();
          });

          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: device.size.width,
                height: device.size.height,
                child: store.storeScreenshotAppForScenario(capture.scenario),
              ),
            ),
          );
          final boundaryFinder = find.byKey(boundaryKey);
          await tester.pump();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          });
          await tester.pumpAndSettle(const Duration(milliseconds: 100));

          await expectLater(
            boundaryFinder,
            matchesGoldenFile('../$goldenPath'),
          );
        });
      }
    });
  }
}

Future<void> _loadStoreAssetFonts() async {
  await _loadFont('Roboto', '/System/Library/Fonts/SFNS.ttf');
  await _loadFont(
    'MaterialIcons',
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

Future<void> _loadFont(String family, String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

class _StoreDevice {
  const _StoreDevice({
    required this.name,
    required this.size,
    required this.outputBase,
  });

  final String name;
  final Size size;
  final String outputBase;
}

class _StoreCapture {
  const _StoreCapture({required this.scenario, required this.output});

  final String scenario;
  final String output;
}
