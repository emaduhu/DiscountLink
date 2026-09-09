import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _scenario = String.fromEnvironment(
  'STORE_SCENARIO',
  defaultValue: 'buyer_marketplace',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(storeScreenshotAppForScenario(_scenario));
}

Widget storeScreenshotAppForScenario(String scenario) {
  return _StoreScreenshotApp(scenario: scenario);
}

class _StoreScreenshotApp extends StatelessWidget {
  const _StoreScreenshotApp({required this.scenario});

  final String scenario;

  @override
  Widget build(BuildContext context) {
    final client = _StoreScreenshotApiClient();
    final page = switch (scenario) {
      'splash' => SplashPage(onContinue: () {}),
      'login' => LoginPage(client: client, onSignedIn: (_, _) {}),
      'seller_marketplace' => _home(
        role: 'seller',
        selectedIndex: 1,
        client: client,
      ),
      'seller_discount_amount' => const _SellerDiscountAmountScreenshotPage(),
      'active_orders' => _home(
        role: 'seller',
        selectedIndex: 2,
        client: client,
      ),
      'delivery_tracking' => const _DeliveryTrackingScreenshotPage(),
      'secure_chat' => _home(role: 'buyer', selectedIndex: 2, client: client),
      _ => _home(role: 'buyer', selectedIndex: 0, client: client),
    };
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          GlobalNetworkLoadingOverlay(child: child ?? const SizedBox.shrink()),
      theme: discountLinkTheme(Brightness.light),
      darkTheme: discountLinkTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      home: _StorePromoFrame(scenario: scenario, child: page),
    );
  }
}

class _StorePromoFrame extends StatelessWidget {
  const _StorePromoFrame({required this.scenario, required this.child});

  final String scenario;
  final Widget child;

  ({String title, String subtitle}) get copy => switch (scenario) {
    'splash' => (
      title: 'Discount Link',
      subtitle: 'Deals, sellers, secure checkout, and tracked delivery.',
    ),
    'login' => (
      title: 'Fast secure access',
      subtitle: 'Sign in with Google, email, phone, and password.',
    ),
    'seller_marketplace' => (
      title: 'Sellers can shop too',
      subtitle: 'Use one seller account to sell products and buy deals.',
    ),
    'seller_discount_amount' => (
      title: 'Fixed amount discounts',
      subtitle: 'TZS 1,000 minus TZS 200 becomes TZS 800.',
    ),
    'active_orders' => (
      title: 'Seller buyer orders',
      subtitle: 'Track purchases and delivery codes from the seller account.',
    ),
    'delivery_tracking' => (
      title: 'Tracked delivery',
      subtitle: 'Follow assigned delivery movement and customer details.',
    ),
    'secure_chat' => (
      title: 'Secure chat',
      subtitle: 'Chat with buyers, sellers, and deliverers in one app.',
    ),
    _ => (
      title: 'Shop better deals',
      subtitle: 'Discover products, discounts, and delivery tracking.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final isTablet = size.width >= 1200;
        final frameWidth = size.width * (isTablet ? 0.72 : 0.78);
        final frameHeight = size.height * (isTablet ? 0.70 : 0.68);
        final logicalWidth = isTablet ? 900.0 : 430.0;
        final logicalHeight = isTablet ? 1180.0 : 932.0;
        final textWidth = size.width * (isTablet ? 0.70 : 0.82);
        final topPadding = size.height * (isTablet ? 0.055 : 0.06);
        final content = copy;

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF3EA),
                  Color(0xFFFF7043),
                  Color(0xFF241A35),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -size.width * 0.18,
                  left: -size.width * 0.18,
                  child: _StoreGlow(size: size.width * 0.55),
                ),
                Positioned(
                  bottom: -size.width * 0.24,
                  right: -size.width * 0.20,
                  child: _StoreGlow(size: size.width * 0.72, dark: true),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    size.width * 0.07,
                    topPadding,
                    size.width * 0.07,
                    size.height * 0.055,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isTablet ? 28 : 22,
                            ),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: isTablet ? 86 : 70,
                              height: isTablet ? 86 : 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Text(
                              kAppName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF20182E),
                                fontSize: isTablet ? 38 : 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: size.height * 0.028),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: textWidth),
                        child: Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 72 : 52,
                            fontWeight: FontWeight.w900,
                            height: 0.98,
                            letterSpacing: -1.4,
                          ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.014),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: textWidth),
                        child: Text(
                          content.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: isTablet ? 31 : 23,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Container(
                          width: frameWidth,
                          height: frameHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              isTablet ? 48 : 38,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.86),
                              width: isTablet ? 12 : 8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: isTablet ? 44 : 34,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: logicalWidth,
                              height: logicalHeight,
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  size: Size(logicalWidth, logicalHeight),
                                  padding: EdgeInsets.zero,
                                  viewPadding: EdgeInsets.zero,
                                  viewInsets: EdgeInsets.zero,
                                  devicePixelRatio: 1,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoreGlow extends StatelessWidget {
  const _StoreGlow({required this.size, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (dark ? const Color(0xFF4B335C) : Colors.white).withValues(
          alpha: dark ? 0.24 : 0.18,
        ),
      ),
    );
  }
}

Widget _home({
  required String role,
  required int selectedIndex,
  required ApiClient client,
}) {
  return HomePage(
    client: client,
    token: 'store-screenshot-token',
    user: _user(role),
    initialIndex: selectedIndex,
    onSelectedIndexChanged: (_) {},
    onUserChanged: (_) {},
    onSignOut: () async {},
    notificationCount: 3,
    onNotificationInboxChanged: () async {},
    notificationsEnabled: true,
    onNotificationsEnabledChanged: (_) async {},
    onRefreshNotifications: () async => null,
    onShowTestNotification: () {},
  );
}

Map<String, dynamic> _user(String role) {
  final id = switch (role) {
    'seller' => 22,
    'deliverer' => 33,
    _ => 11,
  };
  final name = switch (role) {
    'seller' => 'Mlimani Seller',
    'deliverer' => 'Juma Deliverer',
    _ => 'Asha Buyer',
  };
  return {
    'id': id,
    'name': name,
    'email': 'demo@discountlink.app',
    'role': role,
    'phone': '255700000$id',
    'address': 'Mikocheni, Dar es Salaam',
    'is_active': true,
    'is_available': true,
    'email_verified_at': '2026-09-09T08:00:00Z',
    'phone_verified_at': '2026-09-09T08:00:00Z',
  };
}

class _SellerDiscountAmountScreenshotPage extends StatefulWidget {
  const _SellerDiscountAmountScreenshotPage();

  @override
  State<_SellerDiscountAmountScreenshotPage> createState() =>
      _SellerDiscountAmountScreenshotPageState();
}

class _SellerDiscountAmountScreenshotPageState
    extends State<_SellerDiscountAmountScreenshotPage> {
  final productName = TextEditingController(text: 'Bluetooth Headphones');
  final description = TextEditingController(
    text: 'Wireless headset with all-day battery life.',
  );
  final price = TextEditingController(text: '1000');
  final discount = TextEditingController(text: '200');
  final delivery = TextEditingController(text: '100');
  final stock = TextEditingController(text: '10');
  final money = NumberFormat('#,##0.00');
  String discountMode = productDiscountModeAmount;

  @override
  void dispose() {
    productName.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
    super.dispose();
  }

  double buyerPrice() {
    final amount = optionalDiscountAmount(discount.text);
    final productPrice = requiredProductPrice(price.text);
    return (productPrice - amount).clamp(0, productPrice).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final discountedPrice = buyerPrice();
    final deliveryPrice = double.tryParse(delivery.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: const Text('3'),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveListView(
        maxWidth: kResponsiveContentMaxWidth,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(title: 'List product'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: 501,
                  items: const [
                    DropdownMenuItem(
                      value: 501,
                      child: Text('Mlimani Electronics'),
                    ),
                  ],
                  onChanged: (_) {},
                  decoration: const InputDecoration(labelText: 'Shop'),
                ),
                const SizedBox(height: 12),
                Field(
                  controller: productName,
                  label: 'Product name',
                  icon: Icons.inventory_2_outlined,
                ),
                Field(
                  controller: description,
                  label: 'Description',
                  icon: Icons.notes,
                ),
                Field(
                  controller: price,
                  label: 'Price',
                  icon: Icons.sell_outlined,
                  keyboard: TextInputType.number,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: discountMode,
                    items: const [
                      DropdownMenuItem(
                        value: productDiscountModePercent,
                        child: Text('Percentage off'),
                      ),
                      DropdownMenuItem(
                        value: productDiscountModeAmount,
                        child: Text('Fixed amount off'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      discountMode = value ?? productDiscountModePercent;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Discount type',
                      prefixIcon: Icon(Icons.discount_outlined),
                    ),
                  ),
                ),
                Field(
                  controller: discount,
                  label: 'Discount amount off (TZS)',
                  icon: Icons.payments_outlined,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                Field(
                  controller: delivery,
                  label: 'Delivery price',
                  icon: Icons.delivery_dining,
                  keyboard: TextInputType.number,
                ),
                Field(
                  controller: stock,
                  label: 'Stock',
                  icon: Icons.numbers,
                  keyboard: TextInputType.number,
                ),
                PaymentInfoBox(
                  icon: Icons.local_offer_outlined,
                  active: true,
                  text:
                      'Example: TZS ${money.format(requiredProductPrice(price.text))} price - TZS ${money.format(optionalDiscountAmount(discount.text))} amount off = TZS ${money.format(discountedPrice)} buyer price.',
                ),
                const SizedBox(height: 10),
                PaymentSummaryRow(
                  label: 'Buyer pays',
                  value:
                      'TZS ${money.format(discountedPrice + deliveryPrice)} total',
                  strong: true,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Publish product'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: appSurfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: appShadowColor(context, lightAlpha: 0.08, darkAlpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: appPrimarySoftColor(context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_business_outlined),
              selectedIcon: Icon(Icons.add_business),
              label: 'Sell',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shop',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (_) {},
        ),
      ),
    );
  }
}

class _DeliveryTrackingScreenshotPage extends StatelessWidget {
  const _DeliveryTrackingScreenshotPage();

  @override
  Widget build(BuildContext context) {
    final job = _deliveryJobs.first;
    final order = job['order'] as Map<String, dynamic>;
    final shop = order['shop'] as Map<String, dynamic>;
    final buyer = order['buyer'] as Map<String, dynamic>;
    final delivererLatitude = toDouble(job['deliverer_latitude']);
    final delivererLongitude = toDouble(job['deliverer_longitude']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliverer Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: const Text('3'),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveListView(
        maxWidth: kResponsiveContentMaxWidth,
        padding: const EdgeInsets.all(16),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delivery_dining, color: kPrimaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available for deliveries',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'New nearby delivery requests can be assigned to you.',
                            style: TextStyle(color: appMutedTextColor(context)),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: true, onChanged: (_) {}),
                  ],
                ),
                const SizedBox(height: 8),
                StatusPill(label: 'Updated 09:41:00', color: kPrimaryColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order['reference']}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    StatusPill(label: '${job['status']}', color: kPrimaryColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${order['delivery_address']}',
                  style: TextStyle(color: appMutedTextColor(context)),
                ),
                const SizedBox(height: 10),
                TrackingMiniMap(
                  shopLatitude: toDouble(shop['latitude']),
                  shopLongitude: toDouble(shop['longitude']),
                  delivererLatitude: delivererLatitude,
                  delivererLongitude: delivererLongitude,
                ),
                const SizedBox(height: 10),
                Text(
                  '${shop['name']} → ${buyer['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivery total TZS ${order['delivery_total']}',
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.phone_outlined),
                  label: Text('${buyer['call_phone']}'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: appSurfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: appShadowColor(context, lightAlpha: 0.08, darkAlpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: appPrimarySoftColor(context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining),
              label: 'Deliver',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (_) {},
        ),
      ),
    );
  }
}

class _StoreScreenshotApiClient extends ApiClient {
  _StoreScreenshotApiClient() : super('https://example.test/api');

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    if (path == '/shop-categories') {
      return {
        'categories': ['Electronics', 'Fashion', 'Beauty', 'Groceries', 'Home'],
      };
    }
    if (path == '/products') {
      return {'products': _page(_products)};
    }
    if (path == '/cart') {
      return {
        'items': [
          {'id': 7001, 'quantity': 1, 'product': _products.first},
        ],
      };
    }
    if (path == '/orders/active') {
      return {'orders': _page(_orders)};
    }
    if (path == '/conversations') {
      return {'conversations': _page(_conversations)};
    }
    if (path == '/seller/shops') {
      return {
        'shops': _page([_sellerShop]),
        'registration_fee': {
          'amount': '1000.00',
          'currency': 'TZS',
          'enabled': true,
        },
        'deliverer_invitations': [
          {
            'name': 'Juma Deliverer',
            'phone': '255700000033',
            'sent_at': '2026-09-09T08:30:00Z',
          },
        ],
      };
    }
    if (path == '/seller/campaigns') {
      return {
        'campaigns': _page(_campaigns, pageSize: 5),
        'pricing': {
          'fcm': {
            'unit_price': 0,
            'eligible_recipient_count': 126,
            'estimated_total': 0,
          },
          'sms': {
            'unit_price': 45,
            'eligible_recipient_count': 84,
            'estimated_total': 3780,
          },
        },
      };
    }
    if (path == '/deliveries') {
      return {'jobs': _page(_deliveryJobs), 'is_available': true};
    }
    if (path == '/otp/provider') {
      return {'provider': 'beem'};
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool showBlockingLoader = true,
  }) async {
    return {'message': 'OK'};
  }

  @override
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool showBlockingLoader = true,
  }) async {
    return {'message': 'OK', 'user': _user('buyer')};
  }
}

Map<String, dynamic> _page(List<dynamic> data, {int pageSize = 20}) {
  return {
    'data': data.take(pageSize).toList(),
    'current_page': 1,
    'last_page': data.length > pageSize ? 2 : 1,
    'total': data.length,
  };
}

final _products = <Map<String, dynamic>>[
  {
    'id': 101,
    'name': 'Bluetooth Headphones',
    'description': 'Long battery life with comfortable wireless listening.',
    'price': '1000.00',
    'discount_percent': '0',
    'discount_price': '800.00',
    'delivery_price': '100.00',
    'seller_id': 22,
    'ratings_avg_rating': '4.8',
    'ratings_count': 126,
    'images': ['assets/images/product_headset.png'],
    'media': <dynamic>[],
    'shop': {
      'name': 'Mlimani Electronics',
      'is_open': true,
      'latitude': -6.774,
      'longitude': 39.241,
    },
  },
  {
    'id': 102,
    'name': 'Smart Home Speaker',
    'description': 'Clear sound, compact design, and quick setup.',
    'price': '1500.00',
    'discount_percent': '20',
    'delivery_price': '120.00',
    'seller_id': 22,
    'ratings_avg_rating': '4.6',
    'ratings_count': 88,
    'images': ['assets/images/product_popular_1.png'],
    'media': [
      {'type': 'video', 'url': 'assets/images/product_popular_1.png'},
    ],
    'shop': {
      'name': 'Mlimani Electronics',
      'is_open': true,
      'latitude': -6.774,
      'longitude': 39.241,
    },
  },
  {
    'id': 103,
    'name': 'Weekend Grocery Box',
    'description': 'Fresh essentials ready for doorstep delivery.',
    'price': '56000.00',
    'discount_percent': '8',
    'delivery_price': '2500.00',
    'seller_id': 24,
    'ratings_avg_rating': '4.4',
    'ratings_count': 51,
    'images': ['assets/images/deals_banner.png'],
    'media': <dynamic>[],
    'shop': {
      'name': 'Kinondoni Fresh Mart',
      'is_open': true,
      'latitude': -6.792,
      'longitude': 39.208,
    },
  },
  {
    'id': 104,
    'name': 'Travel Backpack',
    'description': 'Durable daily backpack for work and short trips.',
    'price': '68000.00',
    'discount_percent': '12',
    'delivery_price': '2000.00',
    'seller_id': 25,
    'ratings_avg_rating': '4.7',
    'ratings_count': 39,
    'images': ['assets/images/welcome_image.png'],
    'media': <dynamic>[],
    'shop': {
      'name': 'Masaki Style House',
      'is_open': false,
      'latitude': -6.758,
      'longitude': 39.275,
    },
  },
];

final _sellerShop = {
  'id': 501,
  'name': 'Mlimani Electronics',
  'category': 'Electronics',
  'categories': ['Electronics', 'Home'],
  'address': 'Mikocheni, Dar es Salaam',
  'is_active': true,
  'is_open': true,
  'opening_time': '08:00',
  'closing_time': '20:00',
  'registration_fee_status': 'paid',
  'products': [
    for (final product in _products)
      {
        ...product,
        'auto_total': productTotalPrice(
          Map<String, dynamic>.from(product),
        ).toStringAsFixed(2),
      },
  ],
};

final _campaigns = <Map<String, dynamic>>[
  for (var index = 1; index <= 6; index++)
    {
      'id': index,
      'channel': index.isEven ? 'sms' : 'fcm',
      'status': 'completed',
      'sent_count': 80 + index,
      'recipient_count': 90 + index,
      'total_cost': index.isEven ? '3780.00' : '0.00',
      'product': {'name': 'Campaign Product $index'},
    },
];

final _orders = <Map<String, dynamic>>[
  {
    'id': 9001,
    'reference': 'DL-9001',
    'status': 'on_the_way',
    'delivery_address': 'Mikocheni, Dar es Salaam',
    'grand_total': '900.00',
    'delivery_code': '4287',
    'delivery_code_notice':
        'Share this code only after the order arrives. It releases seller and delivery payments.',
    'items': [
      {'quantity': 1, 'name': 'Bluetooth Headphones'},
      {'quantity': 1, 'name': 'Smart Home Speaker'},
    ],
    'shop': {
      'name': 'Mlimani Electronics',
      'latitude': -6.774,
      'longitude': 39.241,
    },
    'delivery_assignment': {
      'deliverer': {'name': 'Juma Deliverer'},
      'deliverer_latitude': -6.781,
      'deliverer_longitude': 39.229,
      'location_updated_at': '2026-09-09T09:10:00Z',
    },
  },
  {
    'id': 9002,
    'reference': 'DL-9002',
    'status': 'packed',
    'delivery_address': 'Oyster Bay, Dar es Salaam',
    'grand_total': '58500.00',
    'items': [
      {'quantity': 1, 'name': 'Weekend Grocery Box'},
    ],
    'shop': {
      'name': 'Kinondoni Fresh Mart',
      'latitude': -6.792,
      'longitude': 39.208,
    },
    'delivery_assignment': {
      'deliverer': {'name': 'Neema Courier'},
      'deliverer_latitude': -6.786,
      'deliverer_longitude': 39.219,
      'location_updated_at': '2026-09-09T09:04:00Z',
    },
  },
];

final _deliveryJobs = <Map<String, dynamic>>[
  {
    'id': 3001,
    'status': 'accepted',
    'deliverer_latitude': -6.781,
    'deliverer_longitude': 39.229,
    'order': {
      'reference': 'DL-9001',
      'delivery_address': 'Mikocheni, Dar es Salaam',
      'delivery_total': '100.00',
      'buyer': {'name': 'Asha Buyer', 'call_phone': '255700000011'},
      'shop': {
        'name': 'Mlimani Electronics',
        'latitude': -6.774,
        'longitude': 39.241,
      },
    },
  },
  {
    'id': 3002,
    'status': 'broadcast',
    'order': {
      'reference': 'DL-9003',
      'delivery_address': 'Masaki, Dar es Salaam',
      'delivery_total': '2000.00',
      'buyer': {'name': 'Baraka Customer', 'call_phone': '255700000044'},
      'shop': {
        'name': 'Masaki Style House',
        'latitude': -6.758,
        'longitude': 39.275,
      },
    },
  },
];

final _conversations = <Map<String, dynamic>>[
  {
    'id': 8001,
    'user_one_id': 11,
    'user_two_id': 22,
    'user_one': {'id': 11, 'name': 'Asha Buyer', 'role': 'buyer'},
    'user_two': {'id': 22, 'name': 'Mlimani Electronics', 'role': 'seller'},
    'unread_count': 2,
    'messages': [
      {
        'body': 'Can you reserve the headphone deal for delivery today?',
        'created_at': '2026-09-09T09:00:00Z',
      },
    ],
  },
  {
    'id': 8002,
    'user_one_id': 11,
    'user_two_id': 33,
    'user_one': {'id': 11, 'name': 'Asha Buyer', 'role': 'buyer'},
    'user_two': {'id': 33, 'name': 'Juma Deliverer', 'role': 'deliverer'},
    'unread_count': 0,
    'messages': [
      {
        'body': 'I am near the shop and will share tracking shortly.',
        'created_at': '2026-09-09T08:48:00Z',
      },
    ],
  },
  {
    'id': 8003,
    'user_one_id': 44,
    'user_two_id': 11,
    'user_one': {'id': 44, 'name': 'Kinondoni Fresh Mart', 'role': 'seller'},
    'user_two': {'id': 11, 'name': 'Asha Buyer', 'role': 'buyer'},
    'unread_count': 1,
    'messages': [
      {
        'body': 'Your grocery box has a fresh discount today.',
        'created_at': '2026-09-09T07:50:00Z',
      },
    ],
  },
];
