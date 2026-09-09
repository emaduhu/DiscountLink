import 'dart:async';

import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test(
    'login phone identifiers are normalized to Tanzanian country format',
    () {
      expect(normalizeLoginIdentifier('+255 700 000 001'), '255700000001');
      expect(normalizeLoginIdentifier('0700 000 001'), '255700000001');
      expect(normalizeLoginIdentifier('700000001'), '255700000001');
      expect(
        normalizeLoginIdentifier(' BUYER@example.com '),
        'buyer@example.com',
      );
    },
  );

  testWidgets('renders Discount Link login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('login password visibility can be toggled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    final passwordInput = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Field && widget.label == 'Password',
      ),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('registration password visibility can be toggled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    final passwordInput = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Field && widget.label == 'Password',
      ),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('pending Google registration collects a password', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
          pendingSocialProviderName: 'Google',
          pendingSocialPayload: {
            'google_id_token': 'dev-google-token:social@example.com',
            'role': 'buyer',
            'full_name': 'Social Buyer',
          },
        ),
      ),
    );

    expect(find.text('Create password'), findsOneWidget);
    expect(find.text('Email'), findsNothing);

    final passwordInput = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Field && widget.label == 'Create password',
      ),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
  });

  testWidgets('login form width is capped on tablet screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SurfacePanel)).width,
      lessThanOrEqualTo(kResponsiveFormMaxWidth),
    );
  });

  testWidgets('seller home includes marketplace and orders tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final client = _HomePageApiClient();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          client: client,
          token: 'seller-token',
          user: {
            'id': 7,
            'role': 'seller',
            'name': 'Seller Buyer',
            'email': 'seller@example.test',
            'phone': '255700000007',
            'phone_verified_at': '2026-09-09T00:00:00.000000Z',
            'email_verified_at': '2026-09-09T00:00:00.000000Z',
            'address': 'Dar es Salaam',
          },
          initialIndex: 0,
          onSelectedIndexChanged: (_) {},
          onUserChanged: (_) {},
          onSignOut: () async {},
          notificationCount: 0,
          onNotificationInboxChanged: () async {},
          notificationsEnabled: true,
          onNotificationsEnabledChanged: (_) async {},
          onRefreshNotifications: () async => null,
          onShowTestNotification: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(homePageCountForRole('seller'), 5);
    expect(profileIndexForRole('seller'), 4);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(client.getPaths, contains('/products'));
    expect(client.getPaths, contains('/cart'));
    expect(find.text('Popular products'), findsOneWidget);
  });

  testWidgets('seller product details include buyer actions', (tester) async {
    final client = _ProductDetailsApiClient();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsPage(
          client: client,
          user: {'id': 7, 'role': 'seller', 'name': 'Seller Buyer'},
          productId: 77,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Market item'), findsWidgets);
    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.byType(RatingPicker), findsOneWidget);
  });

  testWidgets('section menu opens from side navigation on phone screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final sectionKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveSectionListView(
            menuTitle: 'Menu',
            menuItems: [
              SectionMenuItem(
                label: 'Details',
                icon: Icons.info_outline,
                key: sectionKey,
              ),
            ],
            children: [
              SizedBox(key: sectionKey, height: 200, child: const Text('A')),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SectionJumpChips), findsNothing);
    expect(find.byType(SectionSideMenu), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.byType(SectionSideMenu), findsOneWidget);
    expect(
      tester
          .widget<SectionSideMenu>(find.byType(SectionSideMenu))
          .useTopSafeArea,
      isTrue,
    );
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('section menu keeps full side navigation on tablets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final sectionKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveSectionListView(
            menuTitle: 'Menu',
            menuItems: [
              SectionMenuItem(
                label: 'Details',
                icon: Icons.info_outline,
                key: sectionKey,
              ),
            ],
            children: [
              SizedBox(key: sectionKey, height: 200, child: const Text('A')),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SectionSideMenu), findsOneWidget);
    expect(
      tester
          .widget<SectionSideMenu>(find.byType(SectionSideMenu))
          .useTopSafeArea,
      isFalse,
    );
    expect(tester.getSize(find.byType(SectionSideMenu)).width, kSideMenuWidth);
  });

  testWidgets('product carousel activates only the visible media tile', (
    tester,
  ) async {
    const firstImage = 'assets/images/product_popular_1.png';
    const secondImage = 'assets/images/product_headset.png';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ProductMediaCarousel(
                media: [
                  {'type': 'image', 'url': firstImage},
                  {'type': 'image', 'url': secondImage},
                ],
              ),
            ),
          ),
        ),
      ),
    );

    var activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], firstImage);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], secondImage);
  });

  test('product media sources normalize localhost urls to the API origin', () {
    final sources = productMediaSources({
      'media': [
        {
          'type': 'video',
          'url': 'http://localhost/storage/products/7/videos/demo.mp4',
          'position': 0,
        },
      ],
    }, fallback: 'assets/images/product_popular_1.png');

    expect(
      sources.single['url'],
      'https://dl.vigourtech.net/storage/products/7/videos/demo.mp4',
    );
  });

  test('product image sources normalize cleartext same-host urls', () {
    final sources = productImageSources({
      'images': ['http://dl.vigourtech.net/storage/products/7/images/demo.jpg'],
    }, fallback: 'assets/images/product_popular_1.png');

    expect(
      sources.single,
      'https://dl.vigourtech.net/storage/products/7/images/demo.jpg',
    );
  });

  test('product price helpers derive buyer price from percent discounts', () {
    final product = {
      'price': '1000.00',
      'discount_price': null,
      'discount_percent': '15',
      'delivery_price': '100.00',
      'auto_total': '1100.00',
    };

    expect(productActualPrice(product), 1000);
    expect(productBuyerPrice(product), 850);
    expect(productDeliveryPrice(product), 100);
    expect(productTotalPrice(product), 950);
    expect(productHasDiscount(product), isTrue);
    expect(productDiscountModeForProduct(product), productDiscountModePercent);
    expect(
      productDiscountValueForMode(product, productDiscountModePercent),
      '15',
    );
    expect(
      productDiscountMultipartFields(
        priceText: '1000',
        discountMode: productDiscountModePercent,
        discountText: '15',
      ),
      {'discount_percent': '15'},
    );
  });

  test(
    'product discount helpers convert fixed amount off to discount price',
    () {
      final product = {
        'price': '1000.00',
        'discount_price': '800.00',
        'discount_percent': '0',
        'delivery_price': '100.00',
      };

      expect(productBuyerPrice(product), 800);
      expect(productDiscountAmountOff(product), 200);
      expect(productDiscountModeForProduct(product), productDiscountModeAmount);
      expect(
        productDiscountValueForMode(product, productDiscountModeAmount),
        '200',
      );
      expect(
        productDiscountMultipartFields(
          priceText: '1000',
          discountMode: productDiscountModeAmount,
          discountText: '200',
        ),
        {'discount_percent': '0', 'discount_price': '800'},
      );
      expect(
        productDiscountJsonFields(
          priceText: '1000',
          discountMode: productDiscountModeAmount,
          discountText: '200',
        ),
        {'discount_percent': 0.0, 'discount_price': 800.0},
      );
      expect(
        () => productDiscountMultipartFields(
          priceText: '1000',
          discountMode: productDiscountModeAmount,
          discountText: '1001',
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('chat helpers format message time and outgoing delivery status', () {
    appLanguage.value = AppLanguage.en;
    final unreadOutgoing = {
      'created_at': '2026-07-27T08:09:00',
      'read_at': null,
    };
    final readOutgoing = {
      'created_at': '2026-07-27T08:09:00',
      'read_at': '2026-07-27T08:10:00',
    };

    expect(chatMessageTime(unreadOutgoing['created_at']), '08:09');
    expect(chatMessageTime(null), '');
    expect(chatDeliveryStatus(unreadOutgoing, true), 'Delivered');
    expect(chatDeliveryStatus(readOutgoing, true), 'Read');
    expect(chatDeliveryStatus(unreadOutgoing, false), '');
  });

  testWidgets('product carousel plays visible videos and pauses hidden ones', (
    tester,
  ) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final videoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() {
      VideoPlayerPlatform.instance = previousPlatform;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ProductMediaCarousel(
                media: [
                  {
                    'type': 'image',
                    'url': 'assets/images/product_popular_1.png',
                  },
                  {'type': 'video', 'url': 'https://example.test/product.mp4'},
                  {'type': 'image', 'url': 'assets/images/product_headset.png'},
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(videoPlatform.calls, isNot(contains('play')));

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(videoPlatform.calls, contains('createWithOptions'));
    expect(videoPlatform.calls, contains('play'));

    final playIndex = videoPlatform.calls.lastIndexOf('play');
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final pauseIndex = videoPlatform.calls.lastIndexOf('pause');
    expect(pauseIndex, greaterThan(playIndex));
  });
}

class _ProductDetailsApiClient extends ApiClient {
  _ProductDetailsApiClient() : super('https://example.test');

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    if (path == '/products/77') {
      return {
        'product': {
          'id': 77,
          'seller_id': 12,
          'name': 'Market item',
          'description': 'A product sellers can buy too.',
          'price': '1000.00',
          'discount_percent': '0',
          'delivery_price': '100.00',
          'auto_total': '1100.00',
          'stock': 5,
          'images': ['assets/images/product_popular_1.png'],
          'media': <dynamic>[],
          'shop': {'id': 3, 'name': 'Market shop', 'is_open': true},
        },
      };
    }
    throw StateError('Unexpected GET $path');
  }
}

class _HomePageApiClient extends ApiClient {
  _HomePageApiClient() : super('https://example.test');

  final getPaths = <String>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    getPaths.add(path);
    if (path == '/conversations') {
      return {'conversations': []};
    }
    if (path == '/shop-categories') {
      return {
        'categories': ['Electronics', 'Food'],
      };
    }
    if (path == '/seller/shops') {
      return {
        'shops': {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0},
        'registration_fee': {'amount': 0, 'currency': 'TZS', 'enabled': false},
        'deliverer_invitations': [],
      };
    }
    if (path == '/seller/campaigns') {
      return {
        'campaigns': {
          'data': [],
          'current_page': 1,
          'last_page': 1,
          'total': 0,
        },
        'pricing': {
          'fcm': {
            'unit_price': 0,
            'eligible_recipient_count': 0,
            'estimated_total': 0,
          },
          'sms': {
            'unit_price': 0,
            'eligible_recipient_count': 0,
            'estimated_total': 0,
          },
        },
      };
    }
    if (path == '/products') {
      return {
        'products': {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0},
      };
    }
    if (path == '/cart') {
      return {
        'items': [],
        'service_fee': {
          'rate': 0,
          'amount': 0,
          'currency': 'TZS',
          'enabled': false,
        },
        'summary': {
          'subtotal': 0,
          'delivery_total': 0,
          'service_fee_total': 0,
          'grand_total': 0,
        },
      };
    }
    throw StateError('Unexpected GET $path');
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = <String>[];
  final Map<int, StreamController<VideoEvent>> streams =
      <int, StreamController<VideoEvent>>{};
  int nextPlayerId = 1;

  @override
  Future<void> init() async {
    calls.add('init');
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    return createWithOptions(
      VideoCreationOptions(
        dataSource: dataSource,
        viewType: VideoViewType.textureView,
      ),
    );
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('createWithOptions');
    final playerId = nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    streams[playerId] = stream;
    scheduleMicrotask(() {
      if (!stream.isClosed) {
        stream.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 1),
            size: const Size(100, 100),
          ),
        );
      }
    });

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return streams[playerId]!.stream;
  }

  @override
  Widget buildView(int playerId) {
    return SizedBox(key: ValueKey('fake-video-$playerId'));
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('setLooping');
  }

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await streams.remove(playerId)?.close();
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return Duration.zero;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
