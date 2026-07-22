import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

Future<void> _pumpSellerHub(
  WidgetTester tester,
  _SellerHubApiClient client,
) async {
  // Keep the full monolithic Seller Hub mounted so assertions can target its
  // lower product controls without depending on scroll-driven lazy building.
  await tester.binding.setSurfaceSize(const Size(900, 8000));
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

class _SellerHubApiClient extends ApiClient {
  _SellerHubApiClient() : super('https://example.test/api');

  final shopPagesRequested = <int>[];
  final campaignPagesRequested = <int>[];

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
      return {
        'shops': {
          'data': [_shop()],
          'current_page': 1,
          'last_page': 1,
          'total': 1,
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
            'status': 'completed',
            'sent_count': 3,
            'recipient_count': 3,
            'total_cost': '0.00',
            'product': {'name': 'Campaign Product $index'},
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

  Map<String, dynamic> _shop() => {
    'id': 101,
    'name': 'Seller Hub Shop',
    'category': 'Electronics',
    'categories': ['Electronics'],
    'address': 'Dar es Salaam',
    'is_active': true,
    'is_open': true,
    'opening_time': '08:00',
    'closing_time': '20:00',
    'registration_fee_status': 'paid',
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
