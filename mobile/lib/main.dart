import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';

import 'firebase_options.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dl.vigourtech.net/api',
);
const kAppName = 'Discount Link';
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);
const kPrimaryColor = Color(0xffff7643);
const kPrimaryColor2 = Color(0xffffa53e);
const kPrimaryLightColor = Color(0xffffecdf);
const kTextColor = Color(0xff757575);
const kSurfaceColor = Color(0xfff6f7fb);
const kDefaultPadding = 16.0;
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.en);

enum AppLanguage { en, sw }

String tx(String english, String swahili) =>
    appLanguage.value == AppLanguage.sw ? swahili : english;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const DiscountLinkApp());
}

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
}

Future<UserCredential> signInWithGoogleFirebase() async {
  if (kIsWeb) {
    return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  try {
    return await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
  } on UnimplementedError {
    return signInWithGooglePlugin();
  } on FirebaseAuthException catch (error) {
    if (error.code == 'operation-not-supported-in-this-environment' ||
        error.code == 'web-context-cancelled') {
      return signInWithGooglePlugin();
    }
    rethrow;
  }
}

Future<UserCredential> signInWithGooglePlugin() async {
  try {
    final googleUser = await authenticateGoogleAccount();
    final authorization = await googleAuthorization(googleUser);
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
      accessToken: authorization.accessToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  } on GoogleSignInException catch (error) {
    throw Exception(googleSignInErrorMessage(error));
  }
}

Future<GoogleSignInAccount> authenticateGoogleAccount() async {
  await GoogleSignIn.instance.initialize(
    serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId,
  );
  return GoogleSignIn.instance.authenticate(
    scopeHint: const ['email', 'profile'],
  );
}

Future<GoogleSignInClientAuthorization> googleAuthorization(
  GoogleSignInAccount googleUser,
) async {
  return await googleUser.authorizationClient.authorizationForScopes(const [
        'email',
        'profile',
      ]) ??
      await googleUser.authorizationClient.authorizeScopes(const [
        'email',
        'profile',
      ]);
}

Future<Map<String, dynamic>> googleBackendAuthPayload() async {
  try {
    final googleUser = await authenticateGoogleAccount();
    final authorization = await googleAuthorization(googleUser);
    return {
      'google_access_token': authorization.accessToken,
      '_display_name': googleUser.displayName,
      '_phone': null,
    };
  } on GoogleSignInException catch (error) {
    throw Exception(googleSignInErrorMessage(error));
  }
}

Future<UserCredential> signInWithAppleFirebase() async {
  return FirebaseAuth.instance.signInWithProvider(AppleAuthProvider());
}

String googleSignInErrorMessage(GoogleSignInException error) {
  if (error.code == GoogleSignInExceptionCode.canceled) {
    return 'Google sign-in was cancelled.';
  }
  if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
      error.code == GoogleSignInExceptionCode.providerConfigurationError) {
    return 'Google sign-in is not configured correctly in Firebase. Enable Google sign-in, add the Android SHA keys, and download the updated google-services.json.';
  }
  return error.description ?? 'Google sign-in failed. Please try again.';
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
    registerNotifications();
  }

  Future<void> registerNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await client.post('/me/fcm-token', {'fcm_token': token});
      }
    } catch (_) {}
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
        title: kAppName,
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
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.4),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          cardTheme: const CardThemeData(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
        home: UpgradeAlert(
          upgrader: Upgrader(durationUntilAlertAgain: const Duration(days: 1)),
          showReleaseNotes: false,
          child: showSplash
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
                kAppName,
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

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _send('PUT', path, body: body);
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

  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required List<File> files,
    String fileField = 'product_images[]',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(includeContentType: false));
      request.fields.addAll(fields);
      for (final file in files) {
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
    return _request(() {
      final headers = _headers();
      final encoded = jsonEncode(body ?? {});
      if (method == 'PUT') {
        return http.put(uri, headers: headers, body: encoded);
      }
      return http.post(uri, headers: headers, body: encoded);
    });
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() call,
  ) async {
    final response = await call();
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          throw Exception(first.first.toString());
        }
        throw Exception(first.toString());
      }
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
      final auth = await googleBackendAuthPayload();
      final response = await widget.client.post('/auth/google', {
        if (auth['firebase_id_token'] != null)
          'firebase_id_token': auth['firebase_id_token'],
        if (auth['google_access_token'] != null)
          'google_access_token': auth['google_access_token'],
        'role': role,
        'full_name': auth['_display_name'] ?? 'Google user',
        'phone': auth['_phone'] ?? '',
        'address': '',
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

  Future<void> appleSignIn() async {
    setState(() => loading = true);
    try {
      final credential = await signInWithAppleFirebase();
      final firebaseUser = credential.user;
      final token = await firebaseUser?.getIdToken();
      if (token == null) {
        throw Exception('Firebase did not return an ID token.');
      }
      final response = await widget.client.post('/auth/google', {
        'firebase_id_token': token,
        'role': role,
        'full_name': firebaseUser?.displayName ?? 'Apple user',
        'phone': firebaseUser?.phoneNumber ?? '',
        'address': '',
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

  Future<void> openRegisterPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RegisterPage(client: widget.client, onSignedIn: widget.onSignedIn),
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
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
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.black,
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (!kIsWeb &&
                      (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.macOS)) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: loading ? null : appleSignIn,
                      icon: const Icon(Icons.apple),
                      label: Text(
                        tx('Continue with Apple', 'Endelea na Apple'),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Colors.black,
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: loading ? null : openRegisterPage,
                    child: Text(
                      tx('No account? Register', 'Huna akaunti? Jisajili'),
                    ),
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.client,
    required this.onSignedIn,
  });
  final ApiClient client;
  final void Function(String token, Map<String, dynamic> user) onSignedIn;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController(text: 'Demo Buyer');
  final phone = TextEditingController(text: '255700000001');
  final nida = TextEditingController();
  final address = TextEditingController(text: 'Dar es Salaam');
  final email = TextEditingController();
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

  void completeSignIn(Map<String, dynamic> response) {
    final user = response['user'] as Map<String, dynamic>;
    final codes = response['verification_codes'];
    if (codes is Map<String, dynamic>) {
      user['_verification_codes'] = codes;
    }
    widget.onSignedIn(response['token'] as String, user);
    if (mounted) Navigator.of(context).pop();
  }

  void requireRegistrationDetails({required bool includeEmailPassword}) {
    final missing = <String>[];
    if (role.trim().isEmpty) missing.add(tx('account type', 'aina ya akaunti'));
    if (name.text.trim().isEmpty) missing.add(tx('full name', 'jina kamili'));
    if (includeEmailPassword && email.text.trim().isEmpty) {
      missing.add(tx('email', 'barua pepe'));
    }
    if (phone.text.trim().isEmpty) missing.add(tx('phone', 'simu'));
    if (nida.text.trim().isEmpty) {
      missing.add(tx('NIDA number', 'namba ya NIDA'));
    }
    if (address.text.trim().isEmpty) missing.add(tx('address', 'anwani'));
    if (includeEmailPassword && password.text.isEmpty) {
      missing.add(tx('password', 'nenosiri'));
    }
    if (missing.isNotEmpty) {
      throw Exception(
        '${tx('Complete these fields first:', 'Kamilisha taarifa hizi kwanza:')} ${missing.join(', ')}.',
      );
    }
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      requireRegistrationDetails(includeEmailPassword: true);
      final response = await widget.client.post('/auth/register', {
        'role': role,
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'nida_number': nida.text.trim(),
        'password': password.text,
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
      });
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> googleRegister() async {
    setState(() => loading = true);
    try {
      requireRegistrationDetails(includeEmailPassword: false);
      final auth = await googleBackendAuthPayload();
      final response = await widget.client.post('/auth/google', {
        if (auth['firebase_id_token'] != null)
          'firebase_id_token': auth['firebase_id_token'],
        if (auth['google_access_token'] != null)
          'google_access_token': auth['google_access_token'],
        'role': role,
        'full_name': name.text.trim().isEmpty
            ? (auth['_display_name'] ?? 'Google user')
            : name.text.trim(),
        'phone': phone.text.trim().isEmpty
            ? (auth['_phone'] ?? '')
            : phone.text.trim(),
        'nida_number': nida.text.trim(),
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
      });
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> appleRegister() async {
    setState(() => loading = true);
    try {
      requireRegistrationDetails(includeEmailPassword: false);
      final credential = await signInWithAppleFirebase();
      final firebaseUser = credential.user;
      final token = await firebaseUser?.getIdToken();
      if (token == null) {
        throw Exception('Firebase did not return an ID token.');
      }
      final response = await widget.client.post('/auth/google', {
        'firebase_id_token': token,
        'role': role,
        'full_name': name.text.trim().isEmpty
            ? (firebaseUser?.displayName ?? 'Apple user')
            : name.text.trim(),
        'phone': phone.text.trim().isEmpty
            ? (firebaseUser?.phoneNumber ?? '')
            : phone.text.trim(),
        'nida_number': nida.text.trim(),
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
      });
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    nida.dispose();
    address.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return Scaffold(
      appBar: AppBar(title: Text(tx('Create account', 'Fungua akaunti'))),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const RegisterVisualHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                children: [
                  SurfacePanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tx(
                            'Choose your account type',
                            'Chagua aina ya akaunti',
                          ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        RoleSelector(
                          value: role,
                          onChanged: (value) => setState(() => role = value),
                        ),
                        const SizedBox(height: 10),
                        SectionTitle(
                          title: tx('Fast registration', 'Usajili wa haraka'),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: loading ? null : googleRegister,
                          icon: const Icon(Icons.login),
                          label: Text(
                            tx('Register with Google', 'Jisajili na Google'),
                          ),
                          style: socialButtonStyle(),
                        ),
                        if (showApple) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: loading ? null : appleRegister,
                            icon: const Icon(Icons.apple),
                            label: Text(
                              tx('Register with Apple', 'Jisajili na Apple'),
                            ),
                            style: socialButtonStyle(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SurfacePanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(title: tx('Your details', 'Taarifa zako')),
                        const SizedBox(height: 6),
                        Field(
                          controller: name,
                          label: tx('Full name', 'Jina kamili'),
                          icon: Icons.person_outline,
                        ),
                        Field(
                          controller: email,
                          label: tx('Email', 'Barua pepe'),
                          icon: Icons.alternate_email,
                          keyboard: TextInputType.emailAddress,
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
                          controller: nida,
                          label: tx('NIDA number', 'Namba ya NIDA'),
                          icon: Icons.badge_outlined,
                          keyboard: TextInputType.number,
                        ),
                        Field(
                          controller: address,
                          label: tx('Default address', 'Anwani ya msingi'),
                          icon: Icons.place_outlined,
                        ),
                        Field(
                          controller: password,
                          label: tx('Password', 'Nenosiri'),
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                        FilledButton.icon(
                          onPressed: loading ? null : register,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            loading
                                ? tx('Registering...', 'Inasajili...')
                                : tx('Register', 'Jisajili'),
                          ),
                        ),
                      ],
                    ),
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

class RegisterVisualHeader extends StatelessWidget {
  const RegisterVisualHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/deals_banner.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.42)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/app_icon.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kAppName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tx(
                          'Join buyers, sellers, and deliverers in one discount marketplace.',
                          'Jiunge na wanunuzi, wauzaji, na wasafirishaji kwenye soko moja la punguzo.',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
  void initState() {
    super.initState();
    if (widget.user['email_verified_at'] == null ||
        widget.user['phone_verified_at'] == null) {
      index = profileIndexForRole(widget.user['role'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] as String;
    final pages = <Widget>[
      if (role == 'buyer')
        BuyerPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
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
                  ? kAppName
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

int profileIndexForRole(String role) => switch (role) {
  'buyer' => 3,
  'seller' || 'deliverer' => 2,
  _ => 1,
};

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
  final emailCode = TextEditingController();
  bool sent = false;
  bool emailSent = false;
  bool loading = false;
  bool emailLoading = false;
  String otpProvider = 'beem';
  String? firebaseVerificationId;
  String? visiblePhoneCode;

  @override
  void initState() {
    super.initState();
    final codes = widget.user['_verification_codes'];
    if (codes is Map) {
      visiblePhoneCode = codes['phone']?.toString();
      if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
        code.text = visiblePhoneCode!;
        sent = true;
      }
    }
    loadProvider();
  }

  @override
  void dispose() {
    code.dispose();
    emailCode.dispose();
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
        final r = await widget.client.post('/otp/request', {'phone': phone});
        if (mounted) {
          setState(() {
            visiblePhoneCode = r['phone_code']?.toString();
            if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
              code.text = visiblePhoneCode!;
            }
            sent = true;
          });
        }
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

  Future<void> sendEmailOtp() async {
    setState(() => emailLoading = true);
    try {
      final r = await widget.client.post('/email/otp/request', {});
      final emailWasSent = r['email_otp_sent'] == true;
      if (!emailWasSent) {
        throw Exception(
          r['message'] ??
              tx(
                'Email verification code could not be sent. Check the address and try again.',
                'Kodi ya uthibitishaji wa barua pepe haikuweza kutumwa. Hakiki anwani kisha jaribu tena.',
              ),
        );
      }
      if (mounted) {
        setState(() {
          emailSent = true;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => emailLoading = false);
    }
  }

  Future<void> verifyEmailOtp() async {
    setState(() => emailLoading = true);
    try {
      final r = await widget.client.post('/email/otp/verify', {
        'code': emailCode.text.trim(),
      });
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => emailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneVerified = widget.user['phone_verified_at'] != null;
    final emailVerified = widget.user['email_verified_at'] != null;
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
                          label: emailVerified
                              ? 'Email verified'
                              : 'Email pending',
                          color: emailVerified ? Colors.green : kPrimaryColor,
                        ),
                        StatusPill(
                          label: phoneVerified
                              ? 'Phone verified'
                              : 'Phone pending',
                          color: phoneVerified ? Colors.green : kPrimaryColor,
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
                icon: Icons.email_outlined,
                title: tx('Email', 'Barua pepe'),
                value: widget.user['email'] ?? '',
              ),
              ProfileLine(
                icon: Icons.phone_outlined,
                title: tx('Phone', 'Simu'),
                value: widget.user['phone'] ?? '',
              ),
              ProfileLine(
                icon: Icons.badge_outlined,
                title: tx('NIDA number', 'Namba ya NIDA'),
                value: widget.user['nida_number'] ?? '',
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
                emailVerified
                    ? tx('Email verified', 'Barua pepe imethibitishwa')
                    : tx('Verify email', 'Thibitisha barua pepe'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (!emailVerified) ...[
                VerificationStatusLine(
                  sent: emailSent,
                  visibleCode: null,
                  destination: widget.user['email'] ?? '',
                  pendingText: tx(
                    'Email is pending. Send a code to verify this account.',
                    'Barua pepe haijathibitishwa. Tuma kodi kuthibitisha akaunti.',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: emailLoading ? null : sendEmailOtp,
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: Text(
                    emailSent
                        ? tx('Email code sent again', 'Kodi imetumwa tena')
                        : tx('Send email code', 'Tuma kodi ya barua pepe'),
                  ),
                ),
                Field(
                  controller: emailCode,
                  label: tx('Six digit email code', 'Kodi ya barua pepe'),
                  icon: Icons.password,
                  keyboard: TextInputType.number,
                ),
              ] else
                VerificationStatusLine(
                  sent: true,
                  visibleCode: null,
                  destination: widget.user['email'] ?? '',
                  pendingText: tx(
                    'Email verification is complete.',
                    'Uthibitishaji wa barua pepe umekamilika.',
                  ),
                ),
              if (!emailVerified) ...[
                FilledButton(
                  onPressed: emailLoading ? null : verifyEmailOtp,
                  child: Text(
                    emailLoading
                        ? tx('Checking...', 'Inakagua...')
                        : tx('Verify email', 'Thibitisha barua pepe'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                phoneVerified
                    ? tx('Phone verified', 'Simu imethibitishwa')
                    : '${tx('Verify phone with', 'Thibitisha simu kwa')} ${otpProviderLabel(otpProvider)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (!phoneVerified) ...[
                VerificationStatusLine(
                  sent: sent,
                  visibleCode: visiblePhoneCode,
                  destination: widget.user['phone'] ?? '',
                  pendingText: tx(
                    'Phone is pending. Send an OTP to verify this account.',
                    'Simu haijathibitishwa. Tuma OTP kuthibitisha akaunti.',
                  ),
                ),
                const SizedBox(height: 8),
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
              ] else
                VerificationStatusLine(
                  sent: true,
                  visibleCode: null,
                  destination: widget.user['phone'] ?? '',
                  pendingText: tx(
                    'Phone verification is complete.',
                    'Uthibitishaji wa simu umekamilika.',
                  ),
                ),
              if (!phoneVerified) ...[
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
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class VerificationStatusLine extends StatelessWidget {
  const VerificationStatusLine({
    super.key,
    required this.sent,
    required this.destination,
    required this.pendingText,
    this.visibleCode,
  });

  final bool sent;
  final String destination;
  final String pendingText;
  final String? visibleCode;

  @override
  Widget build(BuildContext context) {
    final code = visibleCode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sent ? 'Code sent to $destination' : pendingText,
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.key_outlined,
                    size: 16,
                    color: kPrimaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Code: $code',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BuyerPage extends StatefulWidget {
  const BuyerPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<BuyerPage> createState() => _BuyerPageState();
}

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final addressLine = TextEditingController();
  final city = TextEditingController(text: 'Dar es Salaam');
  final landmark = TextEditingController();
  final checkoutPhone = TextEditingController();
  List cart = [];
  bool loading = true;
  bool checkingOut = false;

  @override
  void initState() {
    super.initState();
    addressLine.text = widget.user['address'] ?? '';
    checkoutPhone.text = widget.user['phone'] ?? '';
    load();
  }

  @override
  void dispose() {
    addressLine.dispose();
    city.dispose();
    landmark.dispose();
    checkoutPhone.dispose();
    super.dispose();
  }

  String checkoutAddress() => [
    addressLine.text.trim(),
    city.text.trim(),
    landmark.text.trim(),
  ].where((part) => part.isNotEmpty).join(', ');

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() => cart = r['items'] as List);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> removeCartItem(Map<String, dynamic> item) async {
    await widget.client.delete('/cart/${item['product']['id']}');
    await load();
  }

  Future<void> saveAddress() async {
    final r = await widget.client.put('/me', {'address': checkoutAddress()});
    widget.onUserChanged(r['user'] as Map<String, dynamic>);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('Address saved.', 'Anwani imehifadhiwa.'))),
    );
  }

  Future<void> checkout() async {
    setState(() => checkingOut = true);
    try {
      final r = await widget.client.post('/checkout', {
        'delivery_address': checkoutAddress(),
        'phone': checkoutPhone.text.trim(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('USSD push requested'),
          content: Text(
            'Order ${r['order']['reference']}\nBuyer delivery code: ${r['delivery_code'] ?? r['delivery_code_demo']}\n\nKeep this code. Share it only after the order arrives to release seller and delivery payments.',
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
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx('Cart', 'Kikapu'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: '${tx('Cart', 'Kikapu')} (${cart.length})',
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const ListLoadingIndicator()
                  else if (cart.isEmpty)
                    Text(
                      tx(
                        'Add products to start checkout.',
                        'Ongeza bidhaa ili kuanza malipo.',
                      ),
                      style: const TextStyle(color: kTextColor),
                    )
                  else
                    for (final i in cart)
                      Builder(
                        builder: (context) {
                          final item = i as Map<String, dynamic>;
                          final override = item['unit_price_override'];
                          final product = item['product'] as Map;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: kPrimaryLightColor,
                              child: Icon(Icons.shopping_bag_outlined),
                            ),
                            title: Text(product['name']),
                            subtitle: Text(
                              override == null
                                  ? 'Qty ${item['quantity']}'
                                  : 'Qty ${item['quantity']} - negotiated TZS $override',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove item',
                              onPressed: () => removeCartItem(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: tx('Delivery details', 'Taarifa za usafiri'),
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
                  OutlinedButton.icon(
                    onPressed: saveAddress,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(tx('Save address', 'Hifadhi anwani')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: cart.isEmpty || loading || checkingOut
                        ? null
                        : checkout,
                    icon: checkingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: Text(
                      checkingOut
                          ? tx('Requesting payment...', 'Inaomba malipo...')
                          : tx(
                              'Pay with ClickPesa USSD',
                              'Lipa kwa ClickPesa USSD',
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
  }
}

class _BuyerPageState extends State<BuyerPage> {
  final search = TextEditingController();
  List products = [];
  List cart = [];
  XFile? pickedImage;
  String? selectedCategory;
  String? imageSearchMessage;
  List<String> shopCategories = defaultShopCategories;
  final money = NumberFormat('#,##0.00');
  bool loadingProducts = true;
  bool loadingCart = true;
  bool imageSearchActive = false;
  bool searchingImage = false;

  @override
  void initState() {
    super.initState();
    loadCategories();
    load();
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.client.get('/shop-categories');
      final next = ((r['categories'] as List?) ?? [])
          .map((category) => '$category'.trim())
          .where((category) => category.isNotEmpty)
          .toList();
      if (next.isNotEmpty && mounted) setState(() => shopCategories = next);
    } catch (_) {}
  }

  Future<void> load() async {
    setState(() {
      loadingProducts = true;
      loadingCart = true;
    });
    final query = <String, String>{};
    if (search.text.trim().isNotEmpty) query['q'] = search.text.trim();
    if (selectedCategory != null) query['category'] = selectedCategory!;
    try {
      final r = await widget.client.get('/products', query);
      final c = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() {
        products = r['products']['data'] as List;
        cart = c['items'] as List;
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loadingProducts = false;
          loadingCart = false;
        });
      }
    }
  }

  Future<void> loadCartCount() async {
    setState(() => loadingCart = true);
    try {
      final c = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() => cart = c['items'] as List);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loadingCart = false);
    }
  }

  Future<void> imageSearchRun() async {
    final image = pickedImage;
    if (image == null) {
      throw Exception(tx('Upload an image first.', 'Pakia picha kwanza.'));
    }
    setState(() {
      loadingProducts = true;
      searchingImage = true;
      imageSearchMessage = tx(
        'Matching product images...',
        'Inalinganisha picha za bidhaa...',
      );
    });
    try {
      final r = await widget.client.postMultipart(
        '/products/image-search',
        fields: const {},
        file: File(image.path),
      );
      if (!mounted) return;
      setState(() {
        products = r['products'] as List;
        imageSearchActive = true;
        imageSearchMessage = '${r['message'] ?? 'Image search complete.'}';
        selectedCategory = null;
        search.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(imageSearchMessage!)));
    } catch (error) {
      if (mounted) {
        setState(() => imageSearchMessage = '$error');
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingProducts = false;
          searchingImage = false;
        });
      }
    }
  }

  Future<void> pickSearchImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;
    if (!mounted) return;
    setState(() {
      pickedImage = image;
      imageSearchMessage = tx(
        'Image ready. Tap Find matches to compare product photos.',
        'Picha iko tayari. Bonyeza Tafuta zinazofanana kulinganisha picha za bidhaa.',
      );
    });
  }

  Future<void> clearImageSearch() async {
    setState(() {
      pickedImage = null;
      imageSearchActive = false;
      imageSearchMessage = null;
    });
    await load();
  }

  Future<void> startChat(Map<String, dynamic> product) async {
    final sellerId = product['seller_id'];
    if (sellerId == null) {
      throw Exception('Seller contact is not available for this product.');
    }
    final r = await widget.client.post('/conversations', {
      'user_id': sellerId,
      'product_id': product['id'],
    });
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          client: widget.client,
          user: widget.user,
          conversation: r['conversation'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  Future<void> openCartPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      ),
    );
    await loadCartCount();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
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
            cartLoading: loadingCart,
            onCart: openCartPage,
          ),
          const SizedBox(height: 18),
          const DealsBanner(),
          const SizedBox(height: 18),
          SectionTitle(
            title: tx('Search by image', 'Tafuta kwa picha'),
            action: imageSearchActive ? tx('Clear', 'Futa') : null,
            onAction: imageSearchActive ? clearImageSearch : null,
          ),
          const SizedBox(height: 10),
          ImageSearchPreview(
            image: pickedImage,
            active: imageSearchActive,
            searching: searchingImage,
            message: imageSearchMessage,
            onPick: pickSearchImage,
            onSearch: imageSearchRun,
            onClear: clearImageSearch,
          ),
          const SizedBox(height: 18),
          SectionTitle(title: tx('Categories', 'Makundi')),
          const SizedBox(height: 10),
          CategoryStrip(
            categories: categoryViewsFromNames(shopCategories),
            onSelected: (name) {
              selectedCategory = name;
              search.clear();
              load();
            },
          ),
          const SizedBox(height: 18),
          SectionTitle(
            title: imageSearchActive
                ? tx('Visual matches', 'Bidhaa zinazofanana')
                : tx('Popular products', 'Bidhaa maarufu'),
            action: imageSearchActive
                ? tx('Clear', 'Futa')
                : tx('Refresh', 'Onyesha upya'),
            onAction: imageSearchActive ? clearImageSearch : load,
          ),
          const SizedBox(height: 10),
          if (loadingProducts)
            const ListLoadingIndicator()
          else if (products.isEmpty)
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
                    await loadCartCount();
                  },
                  onStartChat: () => startChat(product),
                  onRate: (rating) async {
                    await widget.client.post(
                      '/products/${product['id']}/rating',
                      {'rating': rating},
                    );
                    await load();
                  },
                );
              },
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
  bool loading = true;
  bool refreshing = false;
  DateTime? lastUpdated;

  @override
  void initState() {
    super.initState();
    load(showLoading: true);
    refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => load(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool showLoading = false, bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    if (showLoading && mounted) {
      setState(() => loading = true);
    }
    try {
      final r = await widget.client.get('/orders/active');
      if (mounted) {
        setState(() {
          orders = r['orders'] as List;
          lastUpdated = DateTime.now();
          loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => loading = false);
        if (!silent) showError(context, error);
      }
    } finally {
      refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => load(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionTitle(
          title: 'My orders',
          action: refreshing ? 'Updating' : 'Refresh',
          onAction: refreshing ? null : () => load(showLoading: orders.isEmpty),
        ),
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Updated ${DateFormat('HH:mm').format(lastUpdated!)}',
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        if (loading)
          const ListLoadingIndicator()
        else if (orders.isEmpty)
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
  final delivererName = TextEditingController();
  final delivererPhone = TextEditingController();
  final selectedCategories = <String>{'Electronics'};
  List<String> shopCategories = defaultShopCategories;
  final picker = ImagePicker();
  List<XFile> selectedProductImages = [];
  List shops = [];
  List delivererInvitations = [];
  int? selectedShopId;
  int? editingShopId;
  int? editingProductId;
  _ShopEditDraft? shopDraft;
  _ProductEditDraft? productDraft;
  List<XFile> replacementProductImages = [];
  bool loadingShops = true;
  bool invitingDeliverer = false;

  @override
  void initState() {
    super.initState();
    address.text = widget.user['address'] ?? '';
    loadCategories();
    load();
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.client.get('/shop-categories');
      final next = ((r['categories'] as List?) ?? [])
          .map((category) => '$category'.trim())
          .where((category) => category.isNotEmpty)
          .toList();
      if (next.isEmpty || !mounted) return;
      setState(() {
        shopCategories = next;
        selectedCategories.removeWhere((category) => !next.contains(category));
        if (selectedCategories.isEmpty) selectedCategories.add(next.first);
      });
    } catch (_) {}
  }

  Future<void> load() async {
    setState(() => loadingShops = true);
    try {
      final r = await widget.client.get('/seller/shops');
      if (!mounted) return;
      setState(() {
        shops = r['shops'] as List;
        delivererInvitations = (r['deliverer_invitations'] as List?) ?? [];
        if (shops.isNotEmpty) selectedShopId ??= shops.first['id'] as int;
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loadingShops = false);
    }
  }

  Future<void> pickProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    setState(() => selectedProductImages = images);
  }

  List<String> productImagePaths() {
    return selectedProductImages.map((image) => image.path).toList();
  }

  void startEditShop(Map<String, dynamic> shop) {
    shopDraft?.dispose();
    final categories = <String>{
      ...(((shop['categories'] as List?) ?? [shop['category']])
          .whereType<String>()),
    };
    if (categories.isEmpty) categories.add('Electronics');
    setState(() {
      editingShopId = shop['id'] as int?;
      shopDraft = _ShopEditDraft(
        name: shop['name'] ?? '',
        address: shop['address'] ?? '',
        categories: categories,
      );
    });
  }

  void startEditProduct(Map<String, dynamic> product) {
    productDraft?.dispose();
    setState(() {
      editingProductId = product['id'] as int?;
      replacementProductImages = [];
      productDraft = _ProductEditDraft(product);
    });
  }

  void cancelShopEdit() {
    shopDraft?.dispose();
    setState(() {
      editingShopId = null;
      shopDraft = null;
    });
  }

  void cancelProductEdit() {
    productDraft?.dispose();
    setState(() {
      editingProductId = null;
      productDraft = null;
      replacementProductImages = [];
    });
  }

  Future<void> saveShopEdit(Map<String, dynamic> shop) async {
    final draft = shopDraft;
    if (draft == null) return;
    try {
      await widget.client.put('/shops/${shop['id']}', {
        'name': draft.name.text.trim(),
        'category': draft.categories.first,
        'categories': draft.categories.toList(),
        'address': draft.address.text.trim(),
      });
      cancelShopEdit();
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> pickReplacementProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    setState(() => replacementProductImages = images);
  }

  Future<void> saveProductEdit(Map<String, dynamic> product) async {
    final draft = productDraft;
    if (draft == null) return;
    try {
      if (replacementProductImages.isNotEmpty) {
        if (replacementProductImages.length < 3) {
          throw Exception('Choose at least 3 product images.');
        }
        await widget.client.postMultipartFiles(
          '/products/${product['id']}',
          fields: {
            'name': draft.name.text.trim(),
            'description': draft.description.text.trim(),
            'price': draft.price.text,
            'discount_percent': draft.discount.text,
            'delivery_price': draft.delivery.text,
            'stock': draft.stock.text,
          },
          files: replacementProductImages
              .map((image) => File(image.path))
              .toList(),
        );
      } else {
        await widget.client.put('/products/${product['id']}', {
          'name': draft.name.text.trim(),
          'description': draft.description.text.trim(),
          'price': double.parse(draft.price.text),
          'discount_percent': double.tryParse(draft.discount.text) ?? 0,
          'delivery_price': double.parse(draft.delivery.text),
          'stock': int.parse(draft.stock.text),
        });
      }
      cancelProductEdit();
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> removeProduct(Map<String, dynamic> product) async {
    try {
      await widget.client.delete('/products/${product['id']}');
      if (editingProductId == product['id']) cancelProductEdit();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product removed.')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> inviteDeliverer() async {
    if (delivererPhone.text.trim().isEmpty) {
      showError(context, Exception('Enter the deliverer phone number.'));
      return;
    }

    setState(() => invitingDeliverer = true);
    try {
      final r = await widget.client.post('/seller/deliverer-invitations', {
        'name': delivererName.text.trim(),
        'phone': delivererPhone.text.trim(),
      });
      delivererName.clear();
      delivererPhone.clear();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Deliverer invited.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => invitingDeliverer = false);
    }
  }

  @override
  void dispose() {
    shopName.dispose();
    address.dispose();
    productName.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
    delivererName.dispose();
    delivererPhone.dispose();
    shopDraft?.dispose();
    productDraft?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 168,
      ),
      children: [
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Open shop'),
              const SizedBox(height: 12),
              Field(
                controller: shopName,
                label: 'Shop name',
                icon: Icons.store_outlined,
              ),
              CategoryMultiSelect(
                categories: shopCategories,
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
              SectionTitle(title: 'Add deliverer'),
              const SizedBox(height: 12),
              Field(
                controller: delivererName,
                label: 'Deliverer name',
                icon: Icons.badge_outlined,
              ),
              Field(
                controller: delivererPhone,
                label: 'Deliverer phone',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
              ),
              FilledButton.icon(
                onPressed: invitingDeliverer ? null : inviteDeliverer,
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(
                  invitingDeliverer ? 'Sending invite...' : 'Invite deliverer',
                ),
              ),
              if (delivererInvitations.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Recent invites',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final invite in delivererInvitations.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kPrimaryLightColor,
                          child: Icon(
                            invite['sent_at'] == null
                                ? Icons.schedule_send_outlined
                                : Icons.mark_chat_read_outlined,
                            color: kPrimaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invite['name'] ?? 'Deliverer'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${invite['phone']}',
                                style: const TextStyle(
                                  color: kTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          invite['sent_at'] == null ? 'Saved' : 'Sent',
                          style: TextStyle(
                            color: invite['sent_at'] == null
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'List product'),
              const SizedBox(height: 12),
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
              OutlinedButton.icon(
                onPressed: pickProductImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  selectedProductImages.isEmpty
                      ? 'Choose product images'
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
                              'Choose at least 3 product images from phone.',
                            );
                          }
                          await widget.client.postMultipartFiles(
                            '/shops/$selectedShopId/products',
                            fields: {
                              'name': productName.text,
                              'description': description.text,
                              'price': price.text,
                              'discount_percent': discount.text,
                              'delivery_price': delivery.text,
                              'stock': stock.text,
                            },
                            files: selectedProductImages
                                .map((image) => File(image.path))
                                .toList(),
                          );
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
        const SizedBox(height: 18),
        SectionTitle(title: 'Seller products'),
        const SizedBox(height: 8),
        if (loadingShops) const ListLoadingIndicator(),
        for (final s in shops)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? '',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${((s['categories'] as List?) ?? [s['category']]).where((category) => category != null).join(', ')} - ${s['products']?.length ?? 0} products',
                              style: const TextStyle(color: kTextColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit shop',
                        onPressed: () =>
                            startEditShop(s as Map<String, dynamic>),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  if (editingShopId == s['id'] && shopDraft != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Field(
                              controller: shopDraft!.name,
                              label: 'Shop name',
                              icon: Icons.store,
                            ),
                            CategoryMultiSelect(
                              categories: shopCategories,
                              selected: shopDraft!.categories,
                              onChanged: (next) => setState(() {
                                shopDraft!.categories
                                  ..clear()
                                  ..addAll(next);
                              }),
                            ),
                            Field(
                              controller: shopDraft!.address,
                              label: 'Address',
                              icon: Icons.place_outlined,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: cancelShopEdit,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        saveShopEdit(s as Map<String, dynamic>),
                                    child: const Text('Save shop'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final product in ((s['products'] as List?) ?? []))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                        ),
                                        child: ProductImage(
                                          source: productImageSource(
                                            product as Map<String, dynamic>,
                                            fallback:
                                                'assets/images/product_popular_1.png',
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'TZS ${product['auto_total']} total',
                                          style: const TextStyle(
                                            color: kPrimaryColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${product['stock'] ?? 0} in stock',
                                          style: const TextStyle(
                                            color: kTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        RatingSummary(
                                          product: product,
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit product',
                                    onPressed: () => startEditProduct(product),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove product',
                                    onPressed: () => removeProduct(product),
                                    color: Colors.red.shade700,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              if (editingProductId == product['id'] &&
                                  productDraft != null) ...[
                                const SizedBox(height: 12),
                                Field(
                                  controller: productDraft!.name,
                                  label: 'Product name',
                                  icon: Icons.inventory_2_outlined,
                                ),
                                Field(
                                  controller: productDraft!.description,
                                  label: 'Description',
                                  icon: Icons.notes,
                                ),
                                Field(
                                  controller: productDraft!.price,
                                  label: 'Price',
                                  icon: Icons.sell_outlined,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.discount,
                                  label: 'Discount percent',
                                  icon: Icons.percent,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.delivery,
                                  label: 'Delivery price',
                                  icon: Icons.delivery_dining,
                                  keyboard: TextInputType.number,
                                ),
                                Field(
                                  controller: productDraft!.stock,
                                  label: 'Stock',
                                  icon: Icons.numbers,
                                  keyboard: TextInputType.number,
                                ),
                                OutlinedButton.icon(
                                  onPressed: pickReplacementProductImages,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: Text(
                                    replacementProductImages.isEmpty
                                        ? 'Replace images'
                                        : '${replacementProductImages.length} images chosen',
                                  ),
                                ),
                                if (replacementProductImages.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 64,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) =>
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(
                                                replacementProductImages[index]
                                                    .path,
                                              ),
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 8),
                                      itemCount:
                                          replacementProductImages.length,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: cancelProductEdit,
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            saveProductEdit(product),
                                        child: const Text('Save product'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (((s['products'] as List?) ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'No products in this shop yet.',
                        style: TextStyle(color: kTextColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _ShopEditDraft {
  _ShopEditDraft({
    required String name,
    required String address,
    required Set<String> categories,
  }) : name = TextEditingController(text: name),
       address = TextEditingController(text: address),
       categories = {...categories};

  final TextEditingController name;
  final TextEditingController address;
  final Set<String> categories;

  void dispose() {
    name.dispose();
    address.dispose();
  }
}

class _ProductEditDraft {
  _ProductEditDraft(Map<String, dynamic> product)
    : name = TextEditingController(text: product['name'] ?? ''),
      description = TextEditingController(text: product['description'] ?? ''),
      price = TextEditingController(text: '${product['price'] ?? ''}'),
      discount = TextEditingController(
        text: '${product['discount_percent'] ?? '0'}',
      ),
      delivery = TextEditingController(
        text: '${product['delivery_price'] ?? ''}',
      ),
      stock = TextEditingController(text: '${product['stock'] ?? '0'}');

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController price;
  final TextEditingController discount;
  final TextEditingController delivery;
  final TextEditingController stock;

  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
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
  bool loading = true;

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
    setState(() => loading = true);
    try {
      final r = await widget.client.get('/deliveries');
      if (mounted) setState(() => jobs = r['jobs'] as List);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  Future<void> callBuyer(String phone) async {
    final normalized = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (normalized.isEmpty) return;
    final dial = normalized.startsWith('+') ? normalized : '+$normalized';
    final uri = Uri(scheme: 'tel', path: dial);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open phone dialer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loading)
            const ListLoadingIndicator()
          else if (jobs.isEmpty)
            const EmptyState(
              icon: Icons.delivery_dining_outlined,
              title: 'No delivery jobs',
              subtitle: 'Available delivery requests will appear here.',
            ),
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
                        if ('${j['order']?['buyer']?['call_phone'] ?? ''}'
                            .trim()
                            .isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${j['order']?['buyer']?['call_phone']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                tooltip: 'Call buyer',
                                onPressed: () async {
                                  try {
                                    await callBuyer(
                                      '${j['order']?['buyer']?['call_phone']}',
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    showError(context, error);
                                  }
                                },
                                icon: const Icon(Icons.call),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
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
                          label: 'Buyer delivery code (4 unique digits)',
                          icon: Icons.pin,
                          keyboard: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final deliveryCode = code.text.trim();
                            if (deliveryCode.length != 4 ||
                                deliveryCode.split('').toSet().length != 4) {
                              showError(
                                context,
                                'Enter exactly 4 different digits from the buyer.',
                              );
                              return;
                            }
                            await widget.client.post(
                              '/deliveries/${j['id']}/complete',
                              {'delivery_code': deliveryCode},
                            );
                            await load();
                          },
                          icon: const Icon(Icons.payments),
                          label: const Text(
                            'Confirm code and release payments',
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
  Timer? refreshTimer;
  bool refreshing = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final r = await widget.client.get('/conversations');
      if (mounted) {
        setState(() {
          conversations = r['conversations'] as List;
          loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => loading = false);
        showError(context, error);
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> showStartChatPage() async {
    final conversation = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChatContactsPage(client: widget.client),
      ),
    );
    if (conversation == null || !mounted) return;
    await load();
    if (!mounted) return;
    await openConversation(conversation);
  }

  Future<void> openConversation(Map<String, dynamic> conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          client: widget.client,
          user: widget.user,
          conversation: conversation,
        ),
      ),
    );
    if (!mounted) return;
    await load();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionTitle(title: tx('Chats', 'Mazungumzo')),
            ),
            const SizedBox(height: 8),
            if (loading)
              const ListLoadingIndicator()
            else if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: tx('No conversations yet', 'Bado hakuna mazungumzo'),
                  subtitle: tx(
                    'Start a chat with a seller, buyer, or deliverer.',
                    'Anzisha mazungumzo na muuzaji, mnunuzi, au msafirishaji.',
                  ),
                ),
              ),
            for (final item in conversations)
              ChatListTile(
                conversation: item as Map<String, dynamic>,
                currentUserId: widget.user['id'],
                onTap: () => openConversation(item),
              ),
          ],
        ),
      ),
      Positioned(
        right: 18,
        bottom: 18,
        child: FloatingActionButton.extended(
          onPressed: showStartChatPage,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(tx('New chat', 'Soga jipya')),
        ),
      ),
    ],
  );
}

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final dynamic currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversationOther(conversation, currentUserId);
    final name =
        other?['name'] ??
        '${tx('Conversation', 'Mazungumzo')} #${conversation['id']}';
    final role = other?['role'] ?? '';
    final messages = (conversation['messages'] as List?) ?? [];
    final last = messages.isEmpty
        ? null
        : messages.last as Map<String, dynamic>;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: kPrimaryLightColor,
        child: Text(
          initials(name),
          style: const TextStyle(
            color: kPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        last?['body'] ?? role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class ChatContactsPage extends StatefulWidget {
  const ChatContactsPage({super.key, required this.client});
  final ApiClient client;

  @override
  State<ChatContactsPage> createState() => _ChatContactsPageState();
}

class _ChatContactsPageState extends State<ChatContactsPage> {
  List contacts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await widget.client.get('/chat/contacts');
    if (!mounted) return;
    setState(() {
      contacts = r['contacts'] as List;
      loading = false;
    });
  }

  Future<void> startChat(Map<String, dynamic> contact) async {
    final r = await widget.client.post('/conversations', {
      'user_id': contact['id'],
    });
    if (!mounted) return;
    Navigator.pop(context, r['conversation'] as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx('New chat', 'Soga jipya'))),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: tx('No contacts', 'Hakuna anwani'),
                      subtitle: tx(
                        'Users available for chat will appear here.',
                        'Watumiaji wa kuzungumza nao wataonekana hapa.',
                      ),
                    ),
                  ),
                for (final item in contacts)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: kPrimaryLightColor,
                      child: Text(
                        initials(item['name'] ?? 'DL'),
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${item['role']} - ${item['phone'] ?? ''}'),
                    onTap: () => startChat(item as Map<String, dynamic>),
                  ),
              ],
            ),
          ),
  );
}

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.client,
    required this.user,
    required this.conversation,
  });

  final ApiClient client;
  final Map<String, dynamic> user;
  final Map<String, dynamic> conversation;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final message = TextEditingController();
  final offerPrice = TextEditingController();
  final reportDetails = TextEditingController();
  late Map<String, dynamic> conversation;
  List messages = [];
  bool loading = true;
  bool sendingOffer = false;
  bool moderating = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    conversation = Map<String, dynamic>.from(widget.conversation);
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    message.dispose();
    offerPrice.dispose();
    reportDetails.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final r = await widget.client.get(
      '/conversations/${conversation['id']}/messages',
    );
    if (!mounted) return;
    setState(() {
      conversation = Map<String, dynamic>.from(r['conversation'] as Map);
      messages = (r['messages']['data'] as List?) ?? [];
      loading = false;
    });
  }

  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty) return;
    message.clear();
    await widget.client.post('/conversations/${conversation['id']}/messages', {
      'body': body,
    });
    await load();
  }

  bool get isBlocked => conversation['blocked_at'] != null;

  bool get blockedByMe => conversation['blocked_by_id'] == widget.user['id'];

  Future<void> blockChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block chat?'),
        content: const Text(
          'You will stop new messages and discount offers in this chat until you unblock it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => moderating = true);
    try {
      final r = await widget.client.post(
        '/conversations/${conversation['id']}/block',
        {'reason': 'Blocked from app chat.'},
      );
      if (!mounted) return;
      setState(() {
        conversation = Map<String, dynamic>.from(r['conversation'] as Map);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat blocked.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> unblockChat() async {
    setState(() => moderating = true);
    try {
      final r = await widget.client.post(
        '/conversations/${conversation['id']}/unblock',
        {},
      );
      if (!mounted) return;
      setState(() {
        conversation = Map<String, dynamic>.from(r['conversation'] as Map);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat unblocked.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> reportChat() async {
    reportDetails.clear();
    String reason = 'Harassment or abuse';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Report chat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Harassment or abuse',
                      child: Text('Harassment or abuse'),
                    ),
                    DropdownMenuItem(
                      value: 'Fraud or scam',
                      child: Text('Fraud or scam'),
                    ),
                    DropdownMenuItem(
                      value: 'Unsafe product or request',
                      child: Text('Unsafe product or request'),
                    ),
                    DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reportDetails,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'Add context for the admin team',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Submit report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (submitted != true) return;
    setState(() => moderating = true);
    try {
      await widget.client.post('/conversations/${conversation['id']}/report', {
        'reason': reason,
        'details': reportDetails.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => moderating = false);
    }
  }

  Future<void> openDiscountOffer(String token) async {
    try {
      final r = await widget.client.get('/discount-links/$token');
      if (!mounted) return;
      await showDiscountOfferSheet(
        r['discount_link'] as Map<String, dynamic>,
        r['is_valid'] == true,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> showDiscountOfferSheet(
    Map<String, dynamic> offer,
    bool isValid,
  ) async {
    final product = offer['product'] as Map<String, dynamic>;
    final money = NumberFormat('#,##0.00');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final price = num.tryParse('${offer['discount_price']}') ?? 0;
        final original = num.tryParse('${product['price']}') ?? 0;
        final delivery = num.tryParse('${product['delivery_price']}') ?? 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: ProductImage(
                          source: productImageSource(
                            product,
                            fallback: 'assets/images/product_popular_1.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            product['shop']?['name'] ?? '',
                            style: const TextStyle(color: kTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Offer price: TZS ${money.format(price)}',
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (original > price)
                  Text(
                    'Original: TZS ${money.format(original)}',
                    style: const TextStyle(
                      color: kTextColor,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  'Delivery: TZS ${money.format(delivery)}',
                  style: const TextStyle(color: kTextColor),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isValid
                      ? () async {
                          await widget.client.post(
                            '/discount-links/${offer['token']}/cart',
                            {'quantity': 1},
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Discount offer added to cart.'),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(isValid ? 'Add offer to cart' : 'Offer expired'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showCreateOfferDialog() async {
    offerPrice.clear();
    final product = conversation['product'] as Map<String, dynamic>?;
    if (product == null) return;
    final money = NumberFormat('#,##0.00');
    final productName = product['name'] ?? 'this product';
    final original = num.tryParse('${product['price']}') ?? 0;
    final currentDiscount = num.tryParse('${product['discount_price']}');
    final delivery = num.tryParse('${product['delivery_price']}') ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.42,
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: ProductImage(
                          source: productImageSource(
                            product,
                            fallback: 'assets/images/product_popular_1.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Send discount offer',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _OfferPriceRow(
                          label: 'Original price',
                          value: 'TZS ${money.format(original)}',
                          strong: true,
                        ),
                        if (currentDiscount != null) ...[
                          const Divider(height: 18),
                          _OfferPriceRow(
                            label: 'Current discount price',
                            value: 'TZS ${money.format(currentDiscount)}',
                          ),
                        ],
                        const Divider(height: 18),
                        _OfferPriceRow(
                          label: 'Delivery price',
                          value: 'TZS ${money.format(delivery)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: offerPrice,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Negotiated product price',
                    prefixText: 'TZS ',
                    helperText: 'Enter a price lower than the original price.',
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: sendingOffer
                            ? null
                            : () async {
                                final price = offerPrice.text.trim();
                                if (price.isEmpty) return;
                                setState(() => sendingOffer = true);
                                try {
                                  await widget.client.post(
                                    '/conversations/${conversation['id']}/discount-links',
                                    {'discount_price': price},
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  await load();
                                } catch (error) {
                                  if (context.mounted) {
                                    showError(context, error);
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => sendingOffer = false);
                                  }
                                }
                              },
                        icon: sendingOffer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.local_offer_outlined),
                        label: Text(sendingOffer ? 'Sending...' : 'Send offer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = conversationOther(conversation, widget.user['id']);
    final title =
        other?['name'] ??
        '${tx('Conversation', 'Mazungumzo')} #${conversation['id']}';
    final role = other?['role'];
    final product = conversation['product'] as Map<String, dynamic>?;
    final canSendOffer =
        widget.user['role'] == 'seller' && product != null && !isBlocked;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kPrimaryLightColor,
              child: Text(
                initials(title),
                style: const TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (role != null)
                    Text(
                      role,
                      style: const TextStyle(fontSize: 12, color: kTextColor),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !moderating,
            onSelected: (value) {
              if (value == 'report') reportChat();
              if (value == 'block') blockChat();
              if (value == 'unblock') unblockChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report chat'),
                ),
              ),
              if (isBlocked && blockedByMe)
                const PopupMenuItem(
                  value: 'unblock',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_open_outlined),
                    title: Text('Unblock chat'),
                  ),
                )
              else if (!isBlocked)
                const PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block),
                    title: Text('Block chat'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: const Color(0xfffff1f2),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Color(0xffb91c1c)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blockedByMe
                          ? 'You blocked this chat. Unblock it to send messages.'
                          : 'This chat is blocked. New messages are disabled.',
                      style: const TextStyle(
                        color: Color(0xff7f1d1d),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (product != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: kPrimaryLightColor,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (canSendOffer)
                    TextButton.icon(
                      onPressed: showCreateOfferDialog,
                      icon: const Icon(Icons.sell_outlined),
                      label: const Text('Offer'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      tx('No messages yet.', 'Bado hakuna ujumbe.'),
                      style: const TextStyle(color: kTextColor),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final item = messages[index] as Map<String, dynamic>;
                      final mine = item['sender_id'] == widget.user['id'];
                      return ChatBubble(
                        message: item,
                        mine: mine,
                        onOfferTap: openDiscountOffer,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              color: Colors.white,
              child: isBlocked
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Messaging is disabled for this chat.',
                            style: TextStyle(
                              color: kTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (blockedByMe)
                          TextButton.icon(
                            onPressed: moderating ? null : unblockChat,
                            icon: const Icon(Icons.lock_open_outlined),
                            label: const Text('Unblock'),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: message,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => send(),
                            decoration: InputDecoration(
                              hintText: tx('Message', 'Ujumbe'),
                              filled: true,
                              fillColor: kSurfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: send,
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            fixedSize: const Size(48, 48),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferPriceRow extends StatelessWidget {
  const _OfferPriceRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: kTextColor)),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? Colors.black : kTextColor,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.onOfferTap,
  });
  final Map<String, dynamic> message;
  final bool mine;
  final ValueChanged<String> onOfferTap;

  @override
  Widget build(BuildContext context) {
    final body = '${message['body'] ?? ''}';
    final token = discountOfferToken(body);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: token == null ? null : () => onOfferTap(token),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? const Color(0xffdcf8c6) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: token == null
              ? Text(body)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 18,
                          color: kPrimaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tx('Discount offer', 'Ofa ya punguzo'),
                          style: const TextStyle(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(body.split('\n').first),
                    const SizedBox(height: 6),
                    Text(
                      tx('Tap to open in app', 'Bonyeza kufungua kwenye app'),
                      style: const TextStyle(
                        color: kTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String? discountOfferToken(String body) {
  final match = RegExp(r'discountlink://offer/([A-Za-z0-9]+)').firstMatch(body);
  return match?.group(1);
}

Map<String, dynamic>? conversationOther(
  Map<String, dynamic> conversation,
  dynamic currentUserId,
) {
  final one = conversation['user_one'] as Map<String, dynamic>?;
  final two = conversation['user_two'] as Map<String, dynamic>?;
  return conversation['user_one_id'] == currentUserId ? two : one;
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
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

ButtonStyle socialButtonStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(44),
  visualDensity: VisualDensity.compact,
  foregroundColor: Colors.black,
  side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

class MarketplaceHeader extends StatelessWidget {
  const MarketplaceHeader({
    super.key,
    required this.search,
    required this.onSearch,
    required this.cartCount,
    required this.cartLoading,
    required this.onCart,
  });
  final TextEditingController search;
  final VoidCallback onSearch;
  final int cartCount;
  final bool cartLoading;
  final VoidCallback onCart;

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
          isLabelVisible: cartCount > 0 && !cartLoading,
          child: IconButton(
            onPressed: onCart,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              fixedSize: const Size(52, 52),
            ),
            icon: cartLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_cart_outlined),
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
      borderRadius: BorderRadius.circular(16),
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

class ImageSearchPreview extends StatelessWidget {
  const ImageSearchPreview({
    super.key,
    required this.image,
    required this.active,
    required this.searching,
    required this.onPick,
    required this.onSearch,
    required this.onClear,
    this.message,
  });

  final XFile? image;
  final bool active;
  final bool searching;
  final String? message;
  final Future<void> Function() onPick;
  final Future<void> Function() onSearch;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
    return SurfacePanel(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: selectedImage == null
                ? Container(
                    width: 82,
                    height: 82,
                    color: kPrimaryLightColor,
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: kPrimaryColor,
                      size: 32,
                    ),
                  )
                : Image.file(
                    File(selectedImage.path),
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searching
                      ? tx('Matching uploaded image', 'Inalinganisha picha')
                      : selectedImage == null
                      ? tx('Upload product photo', 'Pakia picha ya bidhaa')
                      : active
                      ? tx('Visual results ready', 'Matokeo ya picha tayari')
                      : tx('Ready to match image', 'Tayari kulinganisha picha'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message ??
                      tx(
                        'Choose a clear product photo. Matching compares images, not product names.',
                        'Chagua picha iliyo wazi. Ulinganishaji hutumia picha, si majina ya bidhaa.',
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: searching ? null : onPick,
                      icon: Icon(
                        selectedImage == null
                            ? Icons.upload_file
                            : Icons.swap_horiz,
                      ),
                      label: Text(
                        selectedImage == null
                            ? tx('Upload', 'Pakia')
                            : tx('Replace', 'Badilisha'),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: selectedImage == null || searching
                          ? null
                          : onSearch,
                      icon: searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        searching
                            ? tx('Matching...', 'Inatafuta...')
                            : tx('Find matches', 'Tafuta zinazofanana'),
                      ),
                    ),
                    if (selectedImage != null || active)
                      TextButton(
                        onPressed: searching ? null : onClear,
                        child: Text(tx('Clear', 'Futa')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryView {
  const CategoryView(this.title, this.icon);
  final String title;
  final IconData icon;
}

const defaultShopCategories = [
  'Electronics',
  'Fashion',
  'Groceries',
  'Books',
  'Art',
  'Home',
  'Other',
];

List<CategoryView> categoryViewsFromNames(List<String> categories) => [
  for (final category in categories)
    CategoryView(category, categoryIcon(category)),
];

IconData categoryIcon(String category) {
  final normalized = category.toLowerCase();
  if (normalized.contains('elect')) return Icons.devices_other;
  if (normalized.contains('fashion') || normalized.contains('cloth')) {
    return Icons.checkroom_outlined;
  }
  if (normalized.contains('grocery') || normalized.contains('food')) {
    return Icons.local_grocery_store_outlined;
  }
  if (normalized.contains('book')) return Icons.menu_book_outlined;
  if (normalized.contains('art')) return Icons.palette_outlined;
  if (normalized.contains('home')) return Icons.home_outlined;
  if (normalized.contains('beauty')) return Icons.spa_outlined;
  if (normalized.contains('sport')) return Icons.sports_soccer_outlined;
  return Icons.category_outlined;
}

double? productRating(Map<String, dynamic> product) {
  final value = product['ratings_avg_rating'];
  if (value == null) return null;
  return double.tryParse('$value');
}

int productRatingCount(Map<String, dynamic> product) {
  final value = product['ratings_count'];
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

int? productImageMatchPercent(Map<String, dynamic> product) {
  final value = product['image_match_percent'];
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse('$value');
}

String productImageSource(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  return productImageSources(product, fallback: fallback).first;
}

List<String> productImageSources(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  final images = product['images'];
  if (images is List) {
    final sources = images
        .map((image) => '$image'.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (sources.isNotEmpty) return sources;
  }
  return [fallback];
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
    required this.onRate,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final original = num.tryParse('${product['price']}') ?? 0;
    final total = num.tryParse('${product['auto_total']}') ?? original;
    final discount = num.tryParse('${product['discount_percent']}') ?? 0;
    final matchPercent = productImageMatchPercent(product);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ProductQuickView(
          product: product,
          money: money,
          imageAsset: imageAsset,
          onAdd: onAdd,
          onStartChat: onStartChat,
          onRate: onRate,
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
                    if (matchPercent != null)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$matchPercent% match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
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
              const SizedBox(height: 4),
              RatingSummary(product: product, compact: true),
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
    required this.onRate,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final total = num.tryParse('${product['auto_total']}') ?? 0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final images = productImageSources(product, fallback: imageAsset);
    final matchPercent = productImageMatchPercent(product);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kDefaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: kSurfaceColor),
                        child: ProductImage(
                          source: images[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                product['name'] ?? 'Product',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product['description'] ?? '',
                style: const TextStyle(color: kTextColor),
              ),
              if (matchPercent != null) ...[
                const SizedBox(height: 8),
                StatusPill(
                  label: '$matchPercent% visual match',
                  color: Colors.black87,
                ),
              ],
              const SizedBox(height: 10),
              RatingSummary(product: product),
              const SizedBox(height: 8),
              RatingPicker(onRate: onRate),
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
        ),
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

class ListLoadingIndicator extends StatelessWidget {
  const ListLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Center(child: CircularProgressIndicator()),
  );
}

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.product, this.compact = false});
  final Map<String, dynamic> product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rating = productRating(product);
    final count = productRatingCount(product);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: Colors.amber.shade700,
          size: compact ? 16 : 20,
        ),
        const SizedBox(width: 3),
        Text(
          rating == null ? 'New' : rating.toStringAsFixed(1),
          style: TextStyle(
            color: rating == null ? kTextColor : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 14,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(color: kTextColor, fontSize: compact ? 11 : 13),
          ),
        ],
      ],
    );
  }
}

class RatingPicker extends StatefulWidget {
  const RatingPicker({super.key, required this.onRate});
  final Future<void> Function(int rating) onRate;

  @override
  State<RatingPicker> createState() => _RatingPickerState();
}

class _RatingPickerState extends State<RatingPicker> {
  int selected = 0;
  bool saving = false;

  Future<void> rate(int value) async {
    setState(() {
      selected = value;
      saving = true;
    });
    try {
      await widget.onRate(value);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rating saved.')));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Rate: ', style: TextStyle(fontWeight: FontWeight.w700)),
        for (var value = 1; value <= 5; value++)
          IconButton(
            tooltip: '$value stars',
            onPressed: saving ? null : () => rate(value),
            icon: Icon(
              value <= selected
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: Colors.amber.shade700,
            ),
          ),
        if (saving)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
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

  static const values = defaultShopCategories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
    required this.categories,
    required this.selected,
    required this.onChanged,
  });
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Shop categories',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final category in categories)
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
    this.maxLength,
    this.inputFormatters,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
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
    final deliveryCode =
        '${order['delivery_code'] ?? order['delivery_code_demo'] ?? ''}'.trim();
    final deliveryCodeNotice =
        '${order['delivery_code_notice'] ?? 'Share this code only after the order arrives. It releases seller and delivery payments.'}';

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
                      'Buyer delivery code\n$deliveryCode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              deliveryCodeNotice,
              style: const TextStyle(
                color: kTextColor,
                fontSize: 12,
                height: 1.3,
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
