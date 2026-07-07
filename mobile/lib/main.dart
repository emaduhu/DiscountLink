import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'firebase_options.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dl.vigourtech.net/api',
);
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
  } catch (_) {}
  runApp(const DiscountLinkApp());
}

class DiscountLinkApp extends StatefulWidget {
  const DiscountLinkApp({super.key});
  @override
  State<DiscountLinkApp> createState() => _DiscountLinkAppState();
}

class _DiscountLinkAppState extends State<DiscountLinkApp> {
  final client = ApiClient(apiBaseUrl);
  Map<String, dynamic>? user;

  void signedIn(String token, Map<String, dynamic> signedUser) {
    setState(() {
      client.token = token;
      user = signedUser;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiscountLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff0f766e),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f8fa),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: user == null
          ? LoginPage(client: client, onSignedIn: signedIn)
          : HomePage(
              client: client,
              user: user!,
              onUserChanged: (u) => setState(() => user = u),
            ),
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _request(() => http.get(uri, headers: _headers()));
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(
      () => http.post(uri, headers: _headers(), body: jsonEncode(body ?? {})),
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() call,
  ) async {
    final response = await call();
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        data['message'] ?? 'Request failed (${response.statusCode})',
      );
    }
    return data;
  }

  Map<String, String> _headers() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.client, required this.onSignedIn});
  final ApiClient client;
  final void Function(String token, Map<String, dynamic> user) onSignedIn;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController(text: 'Demo Buyer');
  final phone = TextEditingController(text: '255700000001');
  final address = TextEditingController(text: 'Dar es Salaam');
  final email = TextEditingController(text: 'buyer@discountlink.local');
  final password = TextEditingController(text: 'password');
  String role = 'buyer';
  bool loading = false;

  Future<String?> fcmToken() async {
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> googleSignIn() async {
    setState(() => loading = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw Exception('Google did not return an ID token.');
      final response = await widget.client.post('/auth/google', {
        'google_id_token': token,
        'role': role,
        'full_name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
      });
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      final response = await widget.client.post('/auth/register', {
        'role': role,
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'password': password.text,
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
      });
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> passwordLogin() async {
    setState(() => loading = true);
    try {
      final response = await widget.client.post('/auth/login', {
        'identifier': email.text.trim(),
        'password': password.text,
        'fcm_token': await fcmToken(),
      });
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            Text(
              'DiscountLink',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Google, or register and log in with email or phone.',
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'buyer',
                  label: Text('Buyer'),
                  icon: Icon(Icons.shopping_bag_outlined),
                ),
                ButtonSegment(
                  value: 'seller',
                  label: Text('Seller'),
                  icon: Icon(Icons.storefront_outlined),
                ),
                ButtonSegment(
                  value: 'deliverer',
                  label: Text('Deliverer'),
                  icon: Icon(Icons.delivery_dining_outlined),
                ),
              ],
              selected: {role},
              onSelectionChanged: (v) => setState(() => role = v.first),
            ),
            const SizedBox(height: 16),
            Field(
              controller: name,
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            Field(
              controller: phone,
              label: 'Phone for OTP and disbursements',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            Field(
              controller: address,
              label: 'Default address',
              icon: Icons.place_outlined,
            ),
            Field(
              controller: email,
              label: 'Email or phone for login',
              icon: Icons.alternate_email,
              keyboard: TextInputType.text,
            ),
            Field(
              controller: password,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : googleSignIn,
              icon: const Icon(Icons.login),
              label: Text(loading ? 'Signing in...' : 'Continue with Google'),
            ),
            FilledButton.tonalIcon(
              onPressed: loading ? null : register,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Register with form'),
            ),
            TextButton.icon(
              onPressed: loading ? null : passwordLogin,
              icon: const Icon(Icons.password),
              label: const Text('Login with password'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] as String;
    final pages = <Widget>[
      if (role == 'buyer') BuyerPage(client: widget.client, user: widget.user),
      if (role == 'buyer') OrdersPage(client: widget.client),
      if (role == 'seller')
        SellerPage(client: widget.client, user: widget.user),
      if (role == 'deliverer') DeliveryPage(client: widget.client),
      ChatPage(client: widget.client),
      ProfilePage(
        client: widget.client,
        user: widget.user,
        onUserChanged: widget.onUserChanged,
      ),
    ];
    final destinations = <NavigationDestination>[
      if (role == 'buyer')
        const NavigationDestination(icon: Icon(Icons.search), label: 'Buy'),
      if (role == 'buyer')
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          label: 'Orders',
        ),
      if (role == 'seller')
        const NavigationDestination(
          icon: Icon(Icons.storefront),
          label: 'Sell',
        ),
      if (role == 'deliverer')
        const NavigationDestination(
          icon: Icon(Icons.delivery_dining),
          label: 'Deliver',
        ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Chat',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DiscountLink ${role[0].toUpperCase()}${role.substring(1)}',
        ),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: destinations,
        onDestinationSelected: (v) => setState(() => index = v),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final code = TextEditingController();
  bool sent = false;
  bool loading = false;
  String otpProvider = 'beem';
  String? firebaseVerificationId;

  @override
  void initState() {
    super.initState();
    loadProvider();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> loadProvider() async {
    try {
      final r = await widget.client.get('/otp/provider');
      if (mounted) setState(() => otpProvider = r['provider'] as String);
    } catch (_) {}
  }

  Future<void> sendOtp() async {
    setState(() => loading = true);
    try {
      final phone = widget.user['phone'] as String;
      if (otpProvider == 'firebase') {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone.startsWith('+') ? phone : '+$phone',
          verificationCompleted: (credential) async {
            final firebaseUser = await FirebaseAuth.instance
                .signInWithCredential(credential);
            final idToken = await firebaseUser.user?.getIdToken();
            if (idToken != null) {
              await verifyFirebaseToken(idToken);
            }
          },
          verificationFailed: (error) {
            if (mounted) showError(context, error.message ?? error);
          },
          codeSent: (verificationId, _) {
            if (mounted) {
              setState(() {
                firebaseVerificationId = verificationId;
                sent = true;
              });
            }
          },
          codeAutoRetrievalTimeout: (verificationId) {
            firebaseVerificationId = verificationId;
          },
        );
      } else {
        await widget.client.post('/otp/request', {'phone': phone});
        if (mounted) setState(() => sent = true);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyFirebaseToken(String idToken) async {
    final r = await widget.client.post('/otp/verify', {
      'phone': widget.user['phone'],
      'firebase_id_token': idToken,
    });
    widget.onUserChanged(r['user'] as Map<String, dynamic>);
  }

  Future<void> verifyOtp() async {
    setState(() => loading = true);
    try {
      if (otpProvider == 'firebase') {
        final verificationId = firebaseVerificationId;
        if (verificationId == null) {
          throw Exception('Request the Firebase code first.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code.text,
        );
        final firebaseUser = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final idToken = await firebaseUser.user?.getIdToken();
        if (idToken == null) throw Exception('Firebase token was not issued.');
        await verifyFirebaseToken(idToken);
      } else {
        final r = await widget.client.post('/otp/verify', {
          'phone': widget.user['phone'],
          'code': code.text,
        });
        widget.onUserChanged(r['user'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.user['phone_verified_at'] != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoCard(
          title: widget.user['name'] ?? '',
          subtitle: '${widget.user['phone']}\n${widget.user['address']}',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  verified
                      ? 'Phone verified'
                      : 'Verify phone with ${otpProviderLabel(otpProvider)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (!verified) ...[
                  FilledButton.icon(
                    onPressed: loading ? null : sendOtp,
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(sent ? 'OTP sent again' : 'Send OTP'),
                  ),
                  Field(
                    controller: code,
                    label: 'Six digit OTP',
                    icon: Icons.password,
                    keyboard: TextInputType.number,
                  ),
                  FilledButton(
                    onPressed: loading ? null : verifyOtp,
                    child: Text(loading ? 'Checking...' : 'Verify'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BuyerPage extends StatefulWidget {
  const BuyerPage({super.key, required this.client, required this.user});
  final ApiClient client;
  final Map<String, dynamic> user;
  @override
  State<BuyerPage> createState() => _BuyerPageState();
}

class _BuyerPageState extends State<BuyerPage> {
  final search = TextEditingController();
  final imageLabel = TextEditingController();
  final address = TextEditingController();
  List products = [];
  List cart = [];
  final money = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    load();
    address.text = widget.user['address'] ?? '';
  }

  Future<void> load() async {
    final r = await widget.client.get('/products', {'q': search.text});
    final c = await widget.client.get('/cart');
    setState(() {
      products = r['products']['data'] as List;
      cart = c['items'] as List;
    });
  }

  Future<void> imageSearchRun() async {
    final r = await widget.client.post('/products/image-search', {
      'image_label': imageLabel.text,
    });
    setState(() => products = r['products'] as List);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Field(
                  controller: search,
                  label: 'Search products',
                  icon: Icons.search,
                ),
              ),
              IconButton.filled(
                onPressed: load,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Field(
                  controller: imageLabel,
                  label: 'Image label search',
                  icon: Icons.image_search,
                ),
              ),
              IconButton.filledTonal(
                onPressed: imageSearchRun,
                icon: const Icon(Icons.image),
              ),
            ],
          ),
          Text('Products', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final p in products)
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: Text(p['name']),
                subtitle: Text(
                  '${p['shop']?['name'] ?? ''}\nTZS ${money.format(num.parse('${p['auto_total']}'))} total',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () async {
                    await widget.client.post('/cart/${p['id']}', {
                      'quantity': 1,
                    });
                    await load();
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Cart (${cart.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final i in cart)
            ListTile(
              title: Text(i['product']['name']),
              subtitle: Text('Qty ${i['quantity']}'),
            ),
          Field(
            controller: address,
            label: 'Delivery address',
            icon: Icons.place_outlined,
          ),
          FilledButton.icon(
            onPressed: cart.isEmpty
                ? null
                : () async {
                    final r = await widget.client.post('/checkout', {
                      'delivery_address': address.text,
                    });
                    if (!context.mounted) {
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('USSD push requested'),
                        content: Text(
                          'Order ${r['order']['reference']}\nDemo delivery code: ${r['delivery_code_demo']}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    await load();
                  },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay with ClickPesa USSD'),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List orders = [];
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final r = await widget.client.get('/orders/active');
    if (mounted) setState(() => orders = r['orders'] as List);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Active orders', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const InfoCard(
            title: 'No active orders',
            subtitle: 'Orders waiting for delivery tracking will appear here.',
          ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TrackingCard(order: order as Map<String, dynamic>),
          ),
      ],
    ),
  );
}

class SellerPage extends StatefulWidget {
  const SellerPage({super.key, required this.client, required this.user});
  final ApiClient client;
  final Map<String, dynamic> user;
  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  final shopName = TextEditingController();
  final category = TextEditingController();
  final address = TextEditingController();
  final productName = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final discount = TextEditingController();
  final delivery = TextEditingController();
  final stock = TextEditingController(text: '10');
  List shops = [];
  int? selectedShopId;

  @override
  void initState() {
    super.initState();
    address.text = widget.user['address'] ?? '';
    load();
  }

  Future<void> load() async {
    final r = await widget.client.get('/seller/shops');
    setState(() {
      shops = r['shops'] as List;
      if (shops.isNotEmpty) selectedShopId ??= shops.first['id'] as int;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Open shop', style: Theme.of(context).textTheme.titleLarge),
        Field(
          controller: shopName,
          label: 'Shop name',
          icon: Icons.store_outlined,
        ),
        Field(
          controller: category,
          label: 'Category',
          icon: Icons.category_outlined,
        ),
        Field(
          controller: address,
          label: 'Address',
          icon: Icons.place_outlined,
        ),
        FilledButton.icon(
          onPressed: () async {
            await widget.client.post('/shops', {
              'name': shopName.text,
              'category': category.text,
              'address': address.text,
            });
            await load();
          },
          icon: const Icon(Icons.add_business),
          label: const Text('Save shop'),
        ),
        const SizedBox(height: 18),
        Text('List product', style: Theme.of(context).textTheme.titleLarge),
        if (shops.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: selectedShopId,
            items: [
              for (final s in shops)
                DropdownMenuItem(value: s['id'] as int, child: Text(s['name'])),
            ],
            onChanged: (v) => setState(() => selectedShopId = v),
            decoration: const InputDecoration(labelText: 'Shop'),
          ),
        Field(
          controller: productName,
          label: 'Product name',
          icon: Icons.inventory_2_outlined,
        ),
        Field(controller: description, label: 'Description', icon: Icons.notes),
        Field(
          controller: price,
          label: 'Price',
          icon: Icons.sell_outlined,
          keyboard: TextInputType.number,
        ),
        Field(
          controller: discount,
          label: 'Discount percent',
          icon: Icons.percent,
          keyboard: TextInputType.number,
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
        FilledButton.icon(
          onPressed: selectedShopId == null
              ? null
              : () async {
                  await widget.client.post('/shops/$selectedShopId/products', {
                    'name': productName.text,
                    'description': description.text,
                    'price': double.parse(price.text),
                    'discount_percent': double.tryParse(discount.text) ?? 0,
                    'delivery_price': double.parse(delivery.text),
                    'stock': int.parse(stock.text),
                    'images': <String>[],
                  });
                  await load();
                },
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Publish product'),
        ),
        const SizedBox(height: 12),
        for (final s in shops)
          InfoCard(
            title: s['name'],
            subtitle:
                '${s['category']} - ${s['products']?.length ?? 0} products',
          ),
      ],
    );
  }
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List jobs = [];
  final code = TextEditingController();
  Timer? locationTimer;
  bool sharingLocation = false;

  @override
  void initState() {
    super.initState();
    load();
    locationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => shareAcceptedLocation(silent: true),
    );
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final r = await widget.client.get('/deliveries');
    if (mounted) setState(() => jobs = r['jobs'] as List);
  }

  Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Turn on location services to share tracking.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track deliveries.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> shareAcceptedLocation({bool silent = false}) async {
    final accepted = jobs
        .where((j) => (j as Map<String, dynamic>)['status'] == 'accepted')
        .cast<Map<String, dynamic>>()
        .toList();
    if (accepted.isEmpty || sharingLocation) return;

    setState(() => sharingLocation = true);
    try {
      final position = await currentPosition();
      for (final job in accepted) {
        await widget.client.post('/deliveries/${job['id']}/location', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      }
      await load();
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery location shared.')),
        );
      }
    } catch (error) {
      if (!silent && mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => sharingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final j in jobs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      j['order']['reference'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${j['order']['delivery_address']}\nTZS ${j['order']['delivery_total']}',
                    ),
                    if (j['status'] == 'broadcast')
                      FilledButton.icon(
                        onPressed: () async {
                          await widget.client.post(
                            '/deliveries/${j['id']}/accept',
                            {},
                          );
                          await load();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Accept delivery'),
                      ),
                    if (j['status'] == 'accepted') ...[
                      const SizedBox(height: 8),
                      TrackingMiniMap(
                        shopLatitude: toDouble(j['order']?['shop']?['latitude']),
                        shopLongitude: toDouble(
                          j['order']?['shop']?['longitude'],
                        ),
                        delivererLatitude: toDouble(j['deliverer_latitude']),
                        delivererLongitude: toDouble(j['deliverer_longitude']),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: sharingLocation
                            ? null
                            : () => shareAcceptedLocation(),
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          sharingLocation
                              ? 'Sharing location...'
                              : 'Share current location',
                        ),
                      ),
                      Field(
                        controller: code,
                        label: 'Buyer delivery code',
                        icon: Icons.pin,
                        keyboard: TextInputType.number,
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await widget.client.post(
                            '/deliveries/${j['id']}/complete',
                            {'delivery_code': code.text},
                          );
                          await load();
                        },
                        icon: const Icon(Icons.payments),
                        label: const Text('Complete and trigger disbursement'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List conversations = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await widget.client.get('/conversations');
    setState(() => conversations = r['conversations'] as List);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Chats', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (conversations.isEmpty)
          const InfoCard(
            title: 'No conversations yet',
            subtitle: 'Conversations start from order or user context.',
          ),
        for (final c in conversations)
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text('Conversation #${c['id']}'),
            subtitle: Text('${(c['messages'] as List?)?.length ?? 0} messages'),
          ),
      ],
    ),
  );
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle),
        ],
      ),
    ),
  );
}

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key, required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final assignment = order['delivery_assignment'] as Map<String, dynamic>?;
    final deliverer = assignment?['deliverer'] as Map<String, dynamic>?;
    final shop = order['shop'] as Map<String, dynamic>?;
    final updatedAt = assignment?['location_updated_at'];
    final delivererLatitude = toDouble(assignment?['deliverer_latitude']);
    final delivererLongitude = toDouble(assignment?['deliverer_longitude']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              order['reference'] ?? 'Order',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${order['status']} - ${order['delivery_address']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            TrackingMiniMap(
              shopLatitude: toDouble(shop?['latitude']),
              shopLongitude: toDouble(shop?['longitude']),
              delivererLatitude: delivererLatitude,
              delivererLongitude: delivererLongitude,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.delivery_dining_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deliverer == null
                        ? 'Waiting for a deliverer'
                        : '${deliverer['name']} ${updatedAt == null ? '' : '- updated ${formatDateTime(updatedAt)}'}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TrackingMiniMap extends StatelessWidget {
  const TrackingMiniMap({
    super.key,
    required this.shopLatitude,
    required this.shopLongitude,
    required this.delivererLatitude,
    required this.delivererLongitude,
  });

  final double? shopLatitude;
  final double? shopLongitude;
  final double? delivererLatitude;
  final double? delivererLongitude;

  @override
  Widget build(BuildContext context) {
    final hasDeliverer = delivererLatitude != null && delivererLongitude != null;
    return SizedBox(
      height: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffe8f3f1),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: TrackingMapPainter(
                  shopLatitude: shopLatitude,
                  shopLongitude: shopLongitude,
                  delivererLatitude: delivererLatitude,
                  delivererLongitude: delivererLongitude,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  primary: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (!hasDeliverer)
                const Center(
                  child: Text('Deliverer location has not been shared yet'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackingMapPainter extends CustomPainter {
  TrackingMapPainter({
    required this.shopLatitude,
    required this.shopLongitude,
    required this.delivererLatitude,
    required this.delivererLongitude,
    required this.textColor,
    required this.primary,
  });

  final double? shopLatitude;
  final double? shopLongitude;
  final double? delivererLatitude;
  final double? delivererLongitude;
  final Color textColor;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final points = <_MapPoint>[
      if (shopLatitude != null && shopLongitude != null)
        _MapPoint('Shop', shopLatitude!, shopLongitude!, Colors.deepOrange),
      if (delivererLatitude != null && delivererLongitude != null)
        _MapPoint('Deliverer', delivererLatitude!, delivererLongitude!, primary),
    ];
    if (points.isEmpty) return;

    final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.001 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.001 ? 0.001 : maxLng - minLng;

    Offset project(_MapPoint point) {
      final x = 24 + ((point.longitude - minLng) / lngSpan) * (size.width - 48);
      final y =
          24 + ((maxLat - point.latitude) / latSpan) * (size.height - 48);
      return Offset(x, y);
    }

    if (points.length > 1) {
      final routePaint = Paint()
        ..color = primary.withValues(alpha: 0.38)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(project(points.first), project(points.last), routePaint);
    }

    for (final point in points) {
      final offset = project(point);
      canvas.drawCircle(offset, 10, Paint()..color = Colors.white);
      canvas.drawCircle(offset, 7, Paint()..color = point.color);
      _drawLabel(canvas, point.label, offset + const Offset(12, -24));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    final painter = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant TrackingMapPainter oldDelegate) =>
      oldDelegate.shopLatitude != shopLatitude ||
      oldDelegate.shopLongitude != shopLongitude ||
      oldDelegate.delivererLatitude != delivererLatitude ||
      oldDelegate.delivererLongitude != delivererLongitude;
}

class _MapPoint {
  _MapPoint(this.label, this.latitude, this.longitude, this.color);
  final String label;
  final double latitude;
  final double longitude;
  final Color color;
}

double? toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('MMM d, HH:mm').format(parsed.toLocal());
}

String otpProviderLabel(String provider) => switch (provider) {
  'firebase' => 'Firebase',
  'infobip' => 'Infobip',
  _ => 'Beem Africa',
};

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
  );
}
