import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('Laravel pagination helpers expose items, totals, and more pages', () {
    final response = {
      'data': [
        {'id': 1},
        {'id': 2},
      ],
      'current_page': 1,
      'last_page': 2,
      'total': 6,
    };

    expect(responseItems(response), hasLength(2));
    expect(responseTotal(response), 6);
    expect(responseHasMore(response), isTrue);
    expect(responseHasMore({...response, 'current_page': 2}), isFalse);
  });

  testWidgets('Seller Hub uses equal compact schedule controls', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client);

    final opensButton = find.byKey(const ValueKey('shop-opening-time'));
    final closesButton = find.byKey(const ValueKey('shop-closing-time'));

    expect(opensButton, findsOneWidget);
    expect(closesButton, findsOneWidget);
    final opensSize = tester.getSize(opensButton);
    final closesSize = tester.getSize(closesButton);
    expect(opensSize.width, closesSize.width);
    expect(opensSize.height, 40);
    expect(closesSize.height, 40);
  });

  testWidgets('Seller Hub keeps payment phone below registration details', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client);

    final registrationInfo = find.ancestor(
      of: find.textContaining('New shops pay'),
      matching: find.byType(PaymentInfoBox),
    );
    final paymentPhone = find.byWidgetPredicate(
      (widget) => widget is Field && widget.label == 'ClickPesa payment phone',
    );

    expect(registrationInfo, findsOneWidget);
    expect(paymentPhone, findsOneWidget);
    expect(
      tester.getTopLeft(paymentPhone).dy -
          tester.getBottomLeft(registrationInfo).dy,
      12,
    );
  });

  testWidgets('campaign pager requests and renders the selected server page', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client);

    const previousKey = ValueKey('campaign-page-previous');
    const nextKey = ValueKey('campaign-page-next');
    expect(client.campaignPagesRequested, [1]);
    expect(find.text('Showing 1–5 of 6 campaigns'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(previousKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(nextKey)).onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.byKey(nextKey));
    await tester.tap(find.byKey(nextKey));
    await tester.pumpAndSettle();

    expect(client.campaignPagesRequested, [1, 2]);
    expect(find.text('Showing 6–6 of 6 campaigns'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(previousKey)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(nextKey)).onPressed,
      isNull,
    );
  });

  testWidgets('shop product pager slices products locally in groups of five', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client);

    const previousKey = ValueKey('shop-101-products-previous');
    const nextKey = ValueKey('shop-101-products-next');
    expect(find.text('Showing 1–5 of 6 products'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(previousKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(nextKey)).onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.byKey(nextKey));
    await tester.tap(find.byKey(nextKey));
    await tester.pump();

    expect(find.text('Showing 6–6 of 6 products'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(previousKey)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(nextKey)).onPressed,
      isNull,
    );
  });

  testWidgets('narrow Seller Hub keeps shop hours parallel above saves', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client, size: const Size(320, 8000));

    final opening = find.byKey(const ValueKey('shop-opening-time'));
    final closing = find.byKey(const ValueKey('shop-closing-time'));
    final create = find.byKey(const ValueKey('save-shop'));
    expect(tester.getTopLeft(opening).dy, tester.getTopLeft(closing).dy);
    expect(
      tester.getTopLeft(create).dy,
      greaterThan(tester.getBottomLeft(closing).dy),
    );

    await tester.tap(find.byKey(const ValueKey('shop-101-edit')));
    await tester.pump();

    final editOpening = find.byKey(const ValueKey('shop-101-opening-time'));
    final editClosing = find.byKey(const ValueKey('shop-101-closing-time'));
    final editSave = find.byKey(const ValueKey('shop-101-save-edit'));
    expect(
      tester.getTopLeft(editOpening).dy,
      tester.getTopLeft(editClosing).dy,
    );
    expect(
      tester.getTopLeft(editSave).dy,
      greaterThan(tester.getBottomLeft(editClosing).dy),
    );
  });

  testWidgets('shop create locks while its USSD request is in flight', (
    tester,
  ) async {
    final request = Completer<Map<String, dynamic>>();
    final client = _SellerHubApiClient(shopCreateRequest: request);
    await _pumpSellerHub(tester, client);

    const saveKey = ValueKey('save-shop');
    await tester.tap(find.byKey(saveKey));
    await tester.pump();

    expect(client.postPaths.where((path) => path == '/shops'), hasLength(1));
    expect(tester.widget<FilledButton>(find.byKey(saveKey)).onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(saveKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(saveKey), warnIfMissed: false);
    expect(client.postPaths.where((path) => path == '/shops'), hasLength(1));
    request.complete({'message': 'Shop created.'});
    await tester.pumpAndSettle();
  });

  testWidgets('failed shop payment retry locks and uses seller endpoint', (
    tester,
  ) async {
    final request = Completer<Map<String, dynamic>>();
    final client = _SellerHubApiClient(
      pendingShop: true,
      shopRetryRequest: request,
    );
    await _pumpSellerHub(tester, client);

    const retryKey = ValueKey('shop-101-registration-payment-resend');
    await tester.tap(find.byKey(retryKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('clickpesa-resend-phone')),
      '255755000701',
    );
    await tester.tap(find.byKey(const ValueKey('clickpesa-resend-confirm')));
    await tester.pump();

    expect(client.postPaths, contains('/seller/shop-payments/701/ussd-push'));
    expect(client.postBodies.last, {
      'registration_payment_phone': '255755000701',
    });
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('clickpesa-resend-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('clickpesa-resend-confirm')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('clickpesa-resend-confirm')),
      warnIfMissed: false,
    );
    expect(
      client.postPaths
          .where((path) => path == '/seller/shop-payments/701/ussd-push')
          .length,
      1,
    );
    request.complete({'message': 'Registration request sent.'});
    await tester.pumpAndSettle();
  });

  testWidgets('campaign payment retry locks while USSD request is in flight', (
    tester,
  ) async {
    final request = Completer<Map<String, dynamic>>();
    final client = _SellerHubApiClient(
      pendingCampaign: true,
      campaignRetryRequest: request,
    );
    await _pumpSellerHub(tester, client);

    const retryKey = ValueKey('campaign-1-payment-resend');
    await tester.tap(find.byKey(retryKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('clickpesa-resend-phone')),
      '255755000801',
    );
    await tester.tap(find.byKey(const ValueKey('clickpesa-resend-confirm')));
    await tester.pump();

    expect(
      client.postPaths,
      contains('/seller/campaign-payments/801/ussd-push'),
    );
    expect(client.postBodies.last, {'payment_phone': '255755000801'});
    expect(tester.widget<IconButton>(find.byKey(retryKey)).onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(retryKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(retryKey), warnIfMissed: false);
    expect(
      client.postPaths
          .where((path) => path == '/seller/campaign-payments/801/ussd-push')
          .length,
      1,
    );
    request.complete({'message': 'Campaign payment request sent.'});
    await tester.pumpAndSettle();
  });

  testWidgets('product create locks while media upload is in flight', (
    tester,
  ) async {
    final request = Completer<Map<String, dynamic>>();
    final client = _SellerHubApiClient(productCreateRequest: request);
    await _pumpSellerHub(tester, client);

    final state = tester.state(find.byType(SellerPage)) as dynamic;
    state.productName.text = 'New product';
    state.description.text = 'New product description';
    state.price.text = '1000';
    state.discount.text = '10';
    state.delivery.text = '100';
    state.stock.text = '10';
    state.selectedProductImages = [
      for (final image in _productImageFiles()) XFile(image.path),
    ];

    final firstPublish = state.publishProduct() as Future<void>;
    await tester.pump();

    const publishKey = ValueKey('publish-product');
    expect(
      client.multipartPaths.where((path) => path == '/shops/101/products'),
      hasLength(1),
    );
    expect(
      tester.widget<FilledButton>(find.byKey(publishKey)).onPressed,
      isNull,
    );
    expect(
      find.descendant(
        of: find.byKey(publishKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await state.publishProduct();
    expect(
      client.multipartPaths.where((path) => path == '/shops/101/products'),
      hasLength(1),
    );

    request.complete({
      'product': {'id': 99},
    });
    await firstPublish;
    await tester.pumpAndSettle();
  });

  testWidgets('shop delete confirms and calls the soft-delete endpoint', (
    tester,
  ) async {
    final client = _SellerHubApiClient();
    await _pumpSellerHub(tester, client);

    await tester.tap(find.byKey(const ValueKey('shop-101-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete shop?'), findsOneWidget);

    await tester.tap(find.text('Delete shop'));
    await tester.pumpAndSettle();

    expect(client.deletePaths, ['/shops/101']);
    expect(find.text('Seller Hub Shop'), findsNothing);
  });
}

Future<void> _pumpSellerHub(
  WidgetTester tester,
  _SellerHubApiClient client, {
  Size size = const Size(900, 8000),
}) async {
  // Keep the full monolithic Seller Hub mounted so assertions can target its
  // lower product controls without depending on scroll-driven lazy building.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SellerPage(
          client: client,
          user: const {
            'id': 10,
            'role': 'seller',
            'address': 'Dar es Salaam',
            'phone': '255700000010',
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<File> _productImageFiles() {
  final tempDir = Directory.systemTemp.createTempSync(
    'discountlink-product-images-',
  );
  addTearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  );
  return [
    for (var index = 0; index < 3; index++)
      File('${tempDir.path}/product-$index.png')..writeAsBytesSync(pixel),
  ];
}

class _SellerHubApiClient extends ApiClient {
  _SellerHubApiClient({
    this.pendingShop = false,
    this.pendingCampaign = false,
    this.shopCreateRequest,
    this.shopRetryRequest,
    this.campaignRetryRequest,
    this.productCreateRequest,
  }) : super('https://example.test/api');

  final bool pendingShop;
  final bool pendingCampaign;
  final Completer<Map<String, dynamic>>? shopCreateRequest;
  final Completer<Map<String, dynamic>>? shopRetryRequest;
  final Completer<Map<String, dynamic>>? campaignRetryRequest;
  final Completer<Map<String, dynamic>>? productCreateRequest;
  final shopPagesRequested = <int>[];
  final campaignPagesRequested = <int>[];
  final postPaths = <String>[];
  final postBodies = <Map<String, dynamic>>[];
  final multipartPaths = <String>[];
  final deletePaths = <String>[];
  bool shopDeleted = false;

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    if (path == '/shop-categories') {
      return {
        'categories': ['Electronics', 'Fashion'],
      };
    }
    if (path == '/seller/shops') {
      shopPagesRequested.add(int.parse(query?['page'] ?? '1'));
      final loadedShops = shopDeleted ? <dynamic>[] : [_shop()];
      return {
        'shops': {
          'data': loadedShops,
          'current_page': 1,
          'last_page': 1,
          'total': loadedShops.length,
        },
        'registration_fee': {
          'amount': '1000.00',
          'currency': 'TZS',
          'enabled': true,
        },
        'deliverer_invitations': <dynamic>[],
      };
    }
    if (path == '/seller/campaigns') {
      final page = int.parse(query?['page'] ?? '1');
      campaignPagesRequested.add(page);
      final campaigns = [
        for (var index = 1; index <= 6; index++)
          {
            'id': index,
            'channel': 'fcm',
            'status': pendingCampaign && index == 1
                ? 'payment_failed'
                : 'completed',
            'sent_count': 3,
            'recipient_count': 3,
            'total_cost': '0.00',
            'product': {'name': 'Campaign Product $index'},
            if (pendingCampaign && index == 1)
              'payment': {'id': 801, 'status': 'failed'},
          },
      ];
      final start = (page - 1) * 5;
      final end = start + 5 < campaigns.length ? start + 5 : campaigns.length;
      return {
        'campaigns': {
          'data': campaigns.sublist(start, end),
          'current_page': page,
          'last_page': 2,
          'total': campaigns.length,
        },
        'pricing': {
          'fcm': {
            'unit_price': 0,
            'eligible_recipient_count': 3,
            'estimated_total': 0,
          },
          'sms': {
            'unit_price': 0,
            'eligible_recipient_count': 2,
            'estimated_total': 0,
          },
        },
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool showBlockingLoader = true,
  }) {
    postPaths.add(path);
    postBodies.add(Map<String, dynamic>.from(body));
    if (path == '/shops') {
      return shopCreateRequest?.future ??
          Future.value({'message': 'Shop created.'});
    }
    if (path == '/seller/shop-payments/701/ussd-push') {
      return shopRetryRequest?.future ??
          Future.value({'message': 'Registration request sent.'});
    }
    if (path == '/seller/campaign-payments/801/ussd-push') {
      return campaignRetryRequest?.future ??
          Future.value({'message': 'Campaign payment request sent.'});
    }
    throw StateError('Unexpected POST $path');
  }

  @override
  Future<Map<String, dynamic>> postMultipartMedia(
    String path, {
    required Map<String, String> fields,
    required List<File> images,
    required List<File> videos,
    bool showBlockingLoader = true,
  }) {
    multipartPaths.add(path);
    if (path == '/shops/101/products') {
      return productCreateRequest?.future ??
          Future.value({
            'product': {'id': 99},
          });
    }
    throw StateError('Unexpected multipart POST $path');
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    bool showBlockingLoader = true,
  }) async {
    deletePaths.add(path);
    if (path == '/shops/101') {
      shopDeleted = true;
      return {'message': 'Shop deleted.'};
    }
    throw StateError('Unexpected DELETE $path');
  }

  Map<String, dynamic> _shop() => {
    'id': 101,
    'name': 'Seller Hub Shop',
    'category': 'Electronics',
    'categories': ['Electronics'],
    'address': 'Dar es Salaam',
    'is_active': !pendingShop,
    'is_open': true,
    'opening_time': '08:00',
    'closing_time': '20:00',
    'registration_fee_status': pendingShop ? 'failed' : 'paid',
    if (pendingShop) 'registration_fee_payment_id': 701,
    if (pendingShop)
      'registration_fee_payment': {'id': 701, 'status': 'failed'},
    'products': [
      for (var index = 1; index <= 6; index++)
        {
          'id': index,
          'name': 'Product $index',
          'description': 'Seller product $index',
          'price': '1000.00',
          'discount_percent': '0',
          'delivery_price': '100.00',
          'auto_total': '1100.00',
          'stock': 10,
          'images': ['assets/images/product_popular_1.png'],
          'media': <dynamic>[],
        },
    ],
  };
}
