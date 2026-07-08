import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dl.vigourtech.net/api',
);
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);
const kPrimaryColor = Color(0xffff7643);
const kPrimaryColor2 = Color(0xffffa53e);
const kPrimaryLightColor = Color(0xffffecdf);
const kTextColor = Color(0xff757575);
const kSurfaceColor = Color(0xfff6f7fb);
const kDefaultPadding = 20.0;
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.en);

enum AppLanguage { en, sw }

String tx(String english, String swahili) =>
    appLanguage.value == AppLanguage.sw ? swahili : english;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  try {
    if (googleServerClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(
        serverClientId: googleServerClientId,
      );
    }
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
  bool showSplash = true;

  void signedIn(String token, Map<String, dynamic> signedUser) {
    setState(() {
      client.token = token;
      user = signedUser;
    });
  }

  Future<void> signedOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    setState(() {
      client.token = null;
      user = null;
      showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, _, _) => MaterialApp(
        title: 'DiscountLink',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: kSurfaceColor,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: kSurfaceColor,
            foregroundColor: Colors.black,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.4),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          cardTheme: const CardThemeData(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ),
        ),
        home: showSplash
            ? SplashPage(onContinue: () => setState(() => showSplash = false))
            : user == null
            ? LoginPage(client: client, onSignedIn: signedIn)
            : HomePage(
                client: client,
                user: user!,
                onUserChanged: (u) => setState(() => user = u),
                onSignOut: signedOut,
              ),
      ),
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/images/welcome_image.png',
                height: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              Text(
                'DiscountLink',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Discounted products, verified sellers, tracked delivery, and fast checkout in one shopping flow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextColor, height: 1.45),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onContinue,
                child: Text(tx('Continue', 'Endelea')),
              ),
            ],
          ),
        ),
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

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() => http.delete(uri, headers: _headers()));
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'image',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(includeContentType: false));
      request.fields.addAll(fields);
      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, file.path),
        );
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
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

  Map<String, String> _headers({bool includeContentType = true}) => {
    'Accept': 'application/json',
    if (includeContentType) 'Content-Type': 'application/json',
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
      if (googleServerClientId.isEmpty) {
        throw Exception(
          'Google Sign-In needs GOOGLE_SERVER_CLIENT_ID. Build the app with the Firebase OAuth Web client ID.',
        );
      }
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
          padding: const EdgeInsets.all(kDefaultPadding),
          children: [
            const SizedBox(height: 12),
            Image.asset(
              'assets/images/welcome_image.png',
              height: 170,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              'Welcome back',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with Google, or use email/phone and password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextColor),
            ),
            const SizedBox(height: 22),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoleSelector(
                    value: role,
                    onChanged: (value) => setState(() => role = value),
                  ),
                  const SizedBox(height: 14),
                  Field(
                    controller: email,
                    label: tx('Email or phone', 'Barua pepe au simu'),
                    icon: Icons.alternate_email,
                    keyboard: TextInputType.text,
                  ),
                  Field(
                    controller: password,
                    label: tx('Password', 'Nenosiri'),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                  FilledButton(
                    onPressed: loading ? null : passwordLogin,
                    child: Text(
                      loading
                          ? tx('Signing in...', 'Inaingia...')
                          : tx('Login', 'Ingia'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: kTextColor),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: loading ? null : googleSignIn,
                    icon: const Icon(Icons.login),
                    label: Text(
                      tx('Continue with Google', 'Endelea na Google'),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.black,
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                tx('Create account with form', 'Fungua akaunti kwa fomu'),
              ),
              subtitle: Text(
                tx(
                  'Buyer, seller, or deliverer registration',
                  'Usajili wa mnunuzi, muuzaji, au msafirishaji',
                ),
              ),
              childrenPadding: EdgeInsets.zero,
              children: [
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Field(
                        controller: name,
                        label: tx('Full name', 'Jina kamili'),
                        icon: Icons.person_outline,
                      ),
                      Field(
                        controller: phone,
                        label: tx(
                          'Phone for OTP and payments',
                          'Simu ya OTP na malipo',
                        ),
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                      Field(
                        controller: address,
                        label: tx('Default address', 'Anwani ya msingi'),
                        icon: Icons.place_outlined,
                      ),
                      FilledButton.icon(
                        onPressed: loading ? null : register,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(tx('Register', 'Jisajili')),
                      ),
                    ],
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

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
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
      ChatPage(client: widget.client, user: widget.user),
      ProfilePage(
        client: widget.client,
        user: widget.user,
        onUserChanged: widget.onUserChanged,
        onSignOut: widget.onSignOut,
      ),
    ];
    final destinations = <NavigationDestination>[
      if (role == 'buyer')
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Shop',
        ),
      if (role == 'buyer')
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
      if (role == 'seller')
        const NavigationDestination(
          icon: Icon(Icons.add_business_outlined),
          selectedIcon: Icon(Icons.add_business),
          label: 'Sell',
        ),
      if (role == 'deliverer')
        const NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Deliver',
        ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: 'Chat',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              role == 'buyer'
                  ? 'DiscountLink'
                  : '${role[0].toUpperCase()}${role.substring(1)} Hub',
            ),
          ],
        ),
      ),
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: index,
          backgroundColor: Colors.transparent,
          indicatorColor: kPrimaryLightColor,
          destinations: destinations,
          onDestinationSelected: (v) => setState(() => index = v),
        ),
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
    required this.onSignOut,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SurfacePanel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: kPrimaryLightColor,
                child: Text(
                  initials(widget.user['name'] ?? 'DL'),
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['name'] ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.user['role']} - ${widget.user['email'] ?? ''}',
                      style: const TextStyle(color: kTextColor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label: verified ? 'Phone verified' : 'Phone pending',
                          color: verified ? Colors.green : kPrimaryColor,
                        ),
                        StatusPill(
                          label: widget.user['is_active'] == true
                              ? 'Active'
                              : 'Blocked',
                          color: widget.user['is_active'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LanguageSwitch(),
              const Divider(height: 24),
              ProfileLine(
                icon: Icons.phone_outlined,
                title: tx('Phone', 'Simu'),
                value: widget.user['phone'] ?? '',
              ),
              ProfileLine(
                icon: Icons.place_outlined,
                title: tx('Address', 'Anwani'),
                value: widget.user['address'] ?? '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                verified
                    ? tx('Phone verified', 'Simu imethibitishwa')
                    : '${tx('Verify phone with', 'Thibitisha simu kwa')} ${otpProviderLabel(otpProvider)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (!verified) ...[
                FilledButton.icon(
                  onPressed: loading ? null : sendOtp,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(
                    sent
                        ? tx('OTP sent again', 'OTP imetumwa tena')
                        : tx('Send OTP', 'Tuma OTP'),
                  ),
                ),
                Field(
                  controller: code,
                  label: tx('Six digit OTP', 'OTP ya tarakimu sita'),
                  icon: Icons.password,
                  keyboard: TextInputType.number,
                ),
                FilledButton(
                  onPressed: loading ? null : verifyOtp,
                  child: Text(
                    loading
                        ? tx('Checking...', 'Inakagua...')
                        : tx('Verify', 'Thibitisha'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(tx('Sign out', 'Toka')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
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
  final addressLine = TextEditingController();
  final city = TextEditingController(text: 'Dar es Salaam');
  final landmark = TextEditingController();
  final checkoutPhone = TextEditingController();
  List products = [];
  List cart = [];
  XFile? pickedImage;
  String? selectedCategory;
  final money = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    load();
    addressLine.text = widget.user['address'] ?? '';
    checkoutPhone.text = widget.user['phone'] ?? '';
  }

  Future<void> load() async {
    final query = <String, String>{};
    if (search.text.trim().isNotEmpty) query['q'] = search.text.trim();
    if (selectedCategory != null) query['category'] = selectedCategory!;
    final r = await widget.client.get('/products', query);
    final c = await widget.client.get('/cart');
    setState(() {
      products = r['products']['data'] as List;
      cart = c['items'] as List;
    });
  }

  Future<void> imageSearchRun() async {
    final image = pickedImage;
    if (image == null) {
      throw Exception(tx('Upload an image first.', 'Pakia picha kwanza.'));
    }
    final r = await widget.client.postMultipart(
      '/products/image-search',
      fields: const {},
      file: File(image.path),
    );
    setState(() => products = r['products'] as List);
  }

  Future<void> pickSearchImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    setState(() => pickedImage = image);
  }

  String checkoutAddress() => [
    addressLine.text.trim(),
    city.text.trim(),
    landmark.text.trim(),
  ].where((part) => part.isNotEmpty).join(', ');

  Future<void> removeCartItem(Map<String, dynamic> item) async {
    await widget.client.delete('/cart/${item['product']['id']}');
    await load();
  }

  Future<void> startChat(Map<String, dynamic> product) async {
    final sellerId = product['seller_id'];
    if (sellerId == null) {
      throw Exception('Seller contact is not available for this product.');
    }
    await widget.client.post('/conversations', {'user_id': sellerId});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat started. Open Chat to continue.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          MarketplaceHeader(
            search: search,
            onSearch: load,
            cartCount: cart.length,
          ),
          const SizedBox(height: 18),
          const DealsBanner(),
          const SizedBox(height: 18),
          SectionTitle(
            title: tx('Categories', 'Makundi'),
            action: tx('Image search', 'Tafuta kwa picha'),
            onAction: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(kDefaultPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx('Search by image', 'Tafuta kwa picha'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickSearchImage,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        pickedImage == null
                            ? tx('Upload image', 'Pakia picha')
                            : tx('Image selected', 'Picha imechaguliwa'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          Navigator.pop(context);
                          await imageSearchRun();
                        } catch (error) {
                          if (mounted) showError(this.context, error);
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: Text(tx('Search', 'Tafuta')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CategoryStrip(
            categories: const [
              CategoryView('Electronics', Icons.devices_other),
              CategoryView('Fashion', Icons.checkroom_outlined),
              CategoryView('Groceries', Icons.local_grocery_store_outlined),
              CategoryView('Books', Icons.menu_book_outlined),
              CategoryView('Other', Icons.category_outlined),
            ],
            onSelected: (name) {
              selectedCategory = name;
              search.clear();
              load();
            },
          ),
          const SizedBox(height: 18),
          SectionTitle(
            title: tx('Popular products', 'Bidhaa maarufu'),
            action: tx('Refresh', 'Onyesha upya'),
            onAction: load,
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: tx('No products found', 'Hakuna bidhaa zilizopatikana'),
              subtitle: tx(
                'Try refreshing or using a different search term.',
                'Jaribu kuonyesha upya au kutumia neno jingine.',
              ),
            )
          else
            GridView.builder(
              itemCount: products.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = products[index] as Map<String, dynamic>;
                return ProductDealCard(
                  product: product,
                  money: money,
                  imageAsset: productImageSource(
                    product,
                    fallback: index.isEven
                        ? 'assets/images/product_headset.png'
                        : 'assets/images/product_popular_1.png',
                  ),
                  onAdd: () async {
                    await widget.client.post('/cart/${product['id']}', {
                      'quantity': 1,
                    });
                    await load();
                  },
                  onStartChat: () => startChat(product),
                );
              },
            ),
          const SizedBox(height: 16),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(title: '${tx('Cart', 'Kikapu')} (${cart.length})'),
                const SizedBox(height: 8),
                if (cart.isEmpty)
                  Text(
                    tx(
                      'Add products to start checkout.',
                      'Ongeza bidhaa ili kuanza malipo.',
                    ),
                    style: const TextStyle(color: kTextColor),
                  )
                else
                  for (final i in cart.take(4))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: kPrimaryLightColor,
                        child: Icon(Icons.shopping_bag_outlined),
                      ),
                      title: Text(i['product']['name']),
                      subtitle: Text('Qty ${i['quantity']}'),
                      trailing: IconButton(
                        tooltip: 'Remove item',
                        onPressed: () =>
                            removeCartItem(i as Map<String, dynamic>),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                const SizedBox(height: 8),
                Field(
                  controller: addressLine,
                  label: tx('Street or area', 'Mtaa au eneo'),
                  icon: Icons.place_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Field(
                        controller: city,
                        label: tx('City', 'Jiji'),
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Field(
                        controller: landmark,
                        label: tx('Landmark', 'Alama ya eneo'),
                        icon: Icons.flag_outlined,
                      ),
                    ),
                  ],
                ),
                Field(
                  controller: checkoutPhone,
                  label: tx('Payment phone', 'Simu ya malipo'),
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                ),
                FilledButton.icon(
                  onPressed: cart.isEmpty
                      ? null
                      : () async {
                          final r = await widget.client.post('/checkout', {
                            'delivery_address': checkoutAddress(),
                            'phone': checkoutPhone.text.trim(),
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
                  label: Text(
                    tx('Pay with ClickPesa USSD', 'Lipa kwa ClickPesa USSD'),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(title: 'My orders', action: 'Refresh', onAction: load),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No active orders',
            subtitle: 'Orders waiting for delivery tracking will appear here.',
          ),
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
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
  final address = TextEditingController();
  final productName = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final discount = TextEditingController();
  final delivery = TextEditingController();
  final stock = TextEditingController(text: '10');
  final imageOne = TextEditingController(
    text: 'assets/images/product_headset.png',
  );
  final imageTwo = TextEditingController(
    text: 'assets/images/product_popular_1.png',
  );
  final imageThree = TextEditingController(
    text: 'assets/images/deals_banner.png',
  );
  final selectedCategories = <String>{'Electronics'};
  final picker = ImagePicker();
  List<XFile> selectedProductImages = [];
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

  Future<void> pickProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    setState(() => selectedProductImages = images.take(3).toList());
  }

  List<String> productImagePaths() {
    final picked = selectedProductImages.map((image) => image.path);
    final typed = [
      imageOne.text,
      imageTwo.text,
      imageThree.text,
    ].map((value) => value.trim()).where((value) => value.isNotEmpty);
    return [...picked, ...typed].take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Open shop'),
              Field(
                controller: shopName,
                label: 'Shop name',
                icon: Icons.store_outlined,
              ),
              CategoryMultiSelect(
                selected: selectedCategories,
                onChanged: (categories) => setState(() {
                  selectedCategories
                    ..clear()
                    ..addAll(categories);
                }),
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
                    'category': selectedCategories.first,
                    'categories': selectedCategories.toList(),
                    'address': address.text,
                  });
                  await load();
                },
                icon: const Icon(Icons.add_business),
                label: const Text('Save shop'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'List product'),
              if (shops.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: selectedShopId,
                  items: [
                    for (final s in shops)
                      DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(s['name']),
                      ),
                  ],
                  onChanged: (v) => setState(() => selectedShopId = v),
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
              Field(
                controller: imageOne,
                label: 'Image 1 URL or path',
                icon: Icons.image_outlined,
              ),
              Field(
                controller: imageTwo,
                label: 'Image 2 URL or path',
                icon: Icons.image_outlined,
              ),
              Field(
                controller: imageThree,
                label: 'Image 3 URL or path',
                icon: Icons.image_outlined,
              ),
              OutlinedButton.icon(
                onPressed: pickProductImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  selectedProductImages.isEmpty
                      ? 'Choose images from phone'
                      : '${selectedProductImages.length} phone images chosen',
                ),
              ),
              if (selectedProductImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(selectedProductImages[index].path),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: selectedProductImages.length,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: selectedShopId == null
                    ? null
                    : () async {
                        try {
                          final images = productImagePaths();
                          if (images.length < 3) {
                            throw Exception(
                              'Choose or enter at least 3 images.',
                            );
                          }
                          await widget.client
                              .post('/shops/$selectedShopId/products', {
                                'name': productName.text,
                                'description': description.text,
                                'price': double.parse(price.text),
                                'discount_percent':
                                    double.tryParse(discount.text) ?? 0,
                                'delivery_price': double.parse(delivery.text),
                                'stock': int.parse(stock.text),
                                'images': images,
                              });
                          setState(() => selectedProductImages = []);
                          await load();
                        } catch (error) {
                          if (context.mounted) showError(context, error);
                        }
                      },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Publish product'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in shops)
          InfoCard(
            title: s['name'],
            subtitle:
                '${((s['categories'] as List?) ?? [s['category']]).where((category) => category != null).join(', ')} - ${s['products']?.length ?? 0} products',
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
    if (!enabled) {
      throw Exception('Turn on location services to share tracking.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track deliveries.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
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
                          shopLatitude: toDouble(
                            j['order']?['shop']?['latitude'],
                          ),
                          shopLongitude: toDouble(
                            j['order']?['shop']?['longitude'],
                          ),
                          delivererLatitude: toDouble(j['deliverer_latitude']),
                          delivererLongitude: toDouble(
                            j['deliverer_longitude'],
                          ),
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
                          label: const Text(
                            'Complete and trigger disbursement',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.client, required this.user});
  final ApiClient client;
  final Map<String, dynamic> user;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List conversations = [];
  List contacts = [];
  final message = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final r = await widget.client.get('/conversations');
    setState(() => conversations = r['conversations'] as List);
  }

  Future<void> loadContacts() async {
    final r = await widget.client.get('/chat/contacts');
    setState(() => contacts = r['contacts'] as List);
  }

  Future<void> startChat(Map<String, dynamic> contact) async {
    await widget.client.post('/conversations', {'user_id': contact['id']});
    await load();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('Chat started.', 'Mazungumzo yameanzishwa.'))),
    );
  }

  Future<void> showStartChatSheet() async {
    await loadContacts();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(kDefaultPadding),
        children: [
          SectionTitle(title: tx('Start chat', 'Anzisha mazungumzo')),
          const SizedBox(height: 8),
          if (contacts.isEmpty)
            EmptyState(
              icon: Icons.people_outline,
              title: tx('No contacts', 'Hakuna anwani'),
              subtitle: tx(
                'Users available for chat will appear here.',
                'Watumiaji wa kuzungumza nao wataonekana hapa.',
              ),
            )
          else
            for (final contact in contacts)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimaryLightColor,
                  child: Text(initials(contact['name'] ?? 'DL')),
                ),
                title: Text(contact['name'] ?? ''),
                subtitle: Text(
                  '${contact['role']} - ${contact['phone'] ?? ''}',
                ),
                trailing: const Icon(Icons.chat_bubble_outline),
                onTap: () => startChat(contact as Map<String, dynamic>),
              ),
        ],
      ),
    );
  }

  Future<void> openConversation(Map<String, dynamic> conversation) async {
    final r = await widget.client.get(
      '/conversations/${conversation['id']}/messages',
    );
    final messages = (r['messages']['data'] as List?) ?? [];
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title: tx('Conversation', 'Mazungumzo')),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        tx('No messages yet.', 'Bado hakuna ujumbe.'),
                        style: const TextStyle(color: kTextColor),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final item = messages[index] as Map<String, dynamic>;
                        final mine = item['sender_id'] == widget.user['id'];
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: mine ? kPrimaryColor : kPrimaryLightColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              item['body'] ?? '',
                              style: TextStyle(
                                color: mine ? Colors.white : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Field(
              controller: message,
              label: tx('Type message', 'Andika ujumbe'),
              icon: Icons.message_outlined,
            ),
            FilledButton.icon(
              onPressed: () async {
                if (message.text.trim().isEmpty) return;
                final navigator = Navigator.of(context);
                await widget.client.post(
                  '/conversations/${conversation['id']}/messages',
                  {'body': message.text.trim()},
                );
                message.clear();
                navigator.pop();
                if (!mounted) return;
                await openConversation(conversation);
              },
              icon: const Icon(Icons.send),
              label: Text(tx('Send', 'Tuma')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          title: tx('Chats', 'Mazungumzo'),
          action: tx('Start chat', 'Anzisha'),
          onAction: showStartChatSheet,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: showStartChatSheet,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(tx('Start chat', 'Anzisha mazungumzo')),
        ),
        const SizedBox(height: 12),
        if (conversations.isEmpty)
          EmptyState(
            icon: Icons.chat_bubble_outline,
            title: tx('No conversations yet', 'Bado hakuna mazungumzo'),
            subtitle: tx(
              'Start a chat with a seller, buyer, or deliverer.',
              'Anzisha mazungumzo na muuzaji, mnunuzi, au msafirishaji.',
            ),
          ),
        for (final c in conversations)
          SurfacePanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: kPrimaryLightColor,
                child: Icon(Icons.chat_bubble_outline, color: kPrimaryColor),
              ),
              title: Text(conversationTitle(c as Map<String, dynamic>)),
              subtitle: Text(
                '${(c['messages'] as List?)?.length ?? 0} ${tx('messages', 'jumbe')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openConversation(c),
            ),
          ),
      ],
    ),
  );

  String conversationTitle(Map<String, dynamic> conversation) {
    final currentId = widget.user['id'];
    final one = conversation['user_one'] as Map<String, dynamic>?;
    final two = conversation['user_two'] as Map<String, dynamic>?;
    final other = conversation['user_one_id'] == currentId ? two : one;
    final name =
        other?['name'] ??
        '${tx('Conversation', 'Mazungumzo')} #${conversation['id']}';
    final role = other?['role'];
    return role == null ? name : '$name - $role';
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const roles = [
      ('buyer', 'Buyer', Icons.shopping_bag_outlined),
      ('seller', 'Seller', Icons.storefront_outlined),
      ('deliverer', 'Deliverer', Icons.delivery_dining_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in roles)
          ChoiceChip(
            selected: value == role.$1,
            label: Text(role.$2),
            avatar: Icon(role.$3, size: 18),
            selectedColor: kPrimaryLightColor,
            checkmarkColor: kPrimaryColor,
            onSelected: (_) => onChanged(role.$1),
          ),
      ],
    );
  }
}

class MarketplaceHeader extends StatelessWidget {
  const MarketplaceHeader({
    super.key,
    required this.search,
    required this.onSearch,
    required this.cartCount,
  });
  final TextEditingController search;
  final VoidCallback onSearch;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: search,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: onSearch,
          style: IconButton.styleFrom(
            backgroundColor: kPrimaryColor,
            fixedSize: const Size(52, 52),
          ),
          icon: const Icon(Icons.search),
        ),
        const SizedBox(width: 10),
        Badge(
          label: Text('$cartCount'),
          isLabelVisible: cartCount > 0,
          child: IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              fixedSize: const Size(52, 52),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ),
      ],
    );
  }
}

class DealsBanner extends StatelessWidget {
  const DealsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/deals_banner.png', fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.32)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Flash discounts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Buy deals with delivery tracking',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class CategoryStrip extends StatelessWidget {
  const CategoryStrip({
    super.key,
    required this.categories,
    required this.onSelected,
  });
  final List<CategoryView> categories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = categories[index];
          return InkWell(
            onTap: () => onSelected(item.title),
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 78,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: kPrimaryLightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: kPrimaryColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryView {
  const CategoryView(this.title, this.icon);
  final String title;
  final IconData icon;
}

String productImageSource(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  final images = product['images'];
  if (images is List && images.isNotEmpty) {
    final first = '${images.first}'.trim();
    if (first.isNotEmpty) return first;
  }
  return fallback;
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.source, this.fit});
  final String source;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: fit ?? BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
      );
    }
    final file = File(source);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
      );
    }
    return Image.asset(
      source,
      fit: fit ?? BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, size: 48),
    );
  }
}

class ProductDealCard extends StatelessWidget {
  const ProductDealCard({
    super.key,
    required this.product,
    required this.money,
    required this.imageAsset,
    required this.onAdd,
    required this.onStartChat,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;

  @override
  Widget build(BuildContext context) {
    final original = num.tryParse('${product['price']}') ?? 0;
    final total = num.tryParse('${product['auto_total']}') ?? original;
    final discount = num.tryParse('${product['discount_percent']}') ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => ProductQuickView(
          product: product,
          money: money,
          imageAsset: imageAsset,
          onAdd: onAdd,
          onStartChat: onStartChat,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Center(child: ProductImage(source: imageAsset)),
                    if (discount > 0)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${discount.toStringAsFixed(0)}% off',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product['name'] ?? 'Product',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                product['shop']?['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextColor, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TZS ${money.format(total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      fixedSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
              if (original > total)
                Text(
                  'TZS ${money.format(original)}',
                  style: const TextStyle(
                    color: kTextColor,
                    decoration: TextDecoration.lineThrough,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductQuickView extends StatelessWidget {
  const ProductQuickView({
    super.key,
    required this.product,
    required this.money,
    required this.imageAsset,
    required this.onAdd,
    required this.onStartChat,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;

  @override
  Widget build(BuildContext context) {
    final total = num.tryParse('${product['auto_total']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.all(kDefaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: ProductImage(source: imageAsset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Text(
            product['name'] ?? 'Product',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            product['description'] ?? '',
            style: const TextStyle(color: kTextColor),
          ),
          const SizedBox(height: 12),
          Text(
            'TZS ${money.format(total)} total',
            style: const TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await onAdd();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to cart'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await onStartChat();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Start chat with seller'),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      child: Column(
        children: [
          Icon(icon, color: kTextColor, size: 44),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextColor),
          ),
        ],
      ),
    );
  }
}

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  static const values = [
    'Electronics',
    'Fashion',
    'Groceries',
    'Books',
    'Art',
    'Home',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

class CategoryMultiSelect extends StatelessWidget {
  const CategoryMultiSelect({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Shop categories',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final category in CategoryDropdown.values)
              FilterChip(
                label: Text(category),
                selected: selected.contains(category),
                onSelected: (checked) {
                  final next = {...selected};
                  if (checked) {
                    next.add(category);
                  } else if (next.length > 1) {
                    next.remove(category);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileLine extends StatelessWidget {
  const ProfileLine({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimaryLightColor,
            child: Icon(icon, color: kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: kTextColor, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) => Row(
        children: [
          const CircleAvatar(
            backgroundColor: kPrimaryLightColor,
            child: Icon(Icons.language, color: kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx('Language', 'Lugha'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  tx('Choose app language', 'Chagua lugha ya programu'),
                  style: const TextStyle(color: kTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.en, label: Text('EN')),
              ButtonSegment(value: AppLanguage.sw, label: Text('SW')),
            ],
            selected: {language},
            onSelectionChanged: (selection) {
              appLanguage.value = selection.first;
            },
          ),
        ],
      ),
    );
  }
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
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: kTextColor, height: 1.35)),
      ],
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
    final items = (order['items'] as List?) ?? [];
    final money = NumberFormat('#,##0.00');
    final deliveryCode = '${order['delivery_code_demo'] ?? ''}'.trim();

    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order['reference'] ?? 'Order',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: '${order['status'] ?? 'active'}',
                color: kPrimaryColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order['delivery_address'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextColor),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final item in items.take(3))
              Text(
                '${item['quantity']}x ${item['name']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Total TZS ${money.format(num.tryParse('${order['grand_total']}') ?? 0)}',
            style: const TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (deliveryCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimaryLightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_outlined, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery code $deliveryCode',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final hasDeliverer =
        delivererLatitude != null && delivererLongitude != null;
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
        _MapPoint(
          'Deliverer',
          delivererLatitude!,
          delivererLongitude!,
          primary,
        ),
    ];
    if (points.isEmpty) return;

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() < 0.001 ? 0.001 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 0.001 ? 0.001 : maxLng - minLng;

    Offset project(_MapPoint point) {
      final x = 24 + ((point.longitude - minLng) / lngSpan) * (size.width - 48);
      final y = 24 + ((maxLat - point.latitude) / latSpan) * (size.height - 48);
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
    final painter = TextPainter(text: span, textDirection: ui.TextDirection.ltr)
      ..layout();
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

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? 'DL' : letters;
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
