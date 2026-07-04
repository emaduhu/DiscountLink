import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
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
  String role = 'buyer';
  bool loading = false;

  Future<void> signIn({required bool google}) async {
    setState(() => loading = true);
    try {
      String token = 'dev-google-token:${email.text.trim()}';
      if (google) {
        final account = await GoogleSignIn.instance.authenticate();
        token = account.authentication.idToken ?? token;
      }
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
      final response = await widget.client.post('/auth/google', {
        'google_id_token': token,
        'role': role,
        'full_name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'fcm_token': fcmToken,
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
              'Register with Google, verify your phone, then sell, buy, deliver, and chat.',
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
              label: 'Local dev email',
              icon: Icons.alternate_email,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : () => signIn(google: true),
              icon: const Icon(Icons.login),
              label: Text(loading ? 'Signing in...' : 'Continue with Google'),
            ),
            TextButton(
              onPressed: loading ? null : () => signIn(google: false),
              child: const Text('Use local dev sign-in'),
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
                  verified ? 'Phone verified' : 'Verify phone',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (!verified) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.client.post('/otp/request', {
                        'phone': widget.user['phone'],
                      });
                      setState(() => sent = true);
                    },
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
                    onPressed: () async {
                      final r = await widget.client.post('/otp/verify', {
                        'phone': widget.user['phone'],
                        'code': code.text,
                      });
                      widget.onUserChanged(r['user'] as Map<String, dynamic>);
                    },
                    child: const Text('Verify'),
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
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await widget.client.get('/deliveries');
    setState(() => jobs = r['jobs'] as List);
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
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
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

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
  );
}
