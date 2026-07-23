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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';

import 'firebase_options.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dl.vigourtech.net/api',
);
const kAppName = 'Discount Link';
const playStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue:
      'https://play.google.com/store/apps/details?id=net.vigourtech.dl',
);
const appStoreUrl = String.fromEnvironment(
  'APP_STORE_URL',
  defaultValue: 'https://apps.apple.com/search?term=Vigour%20Deals',
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
const kDefaultPadding = 16.0;
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.en);
const biometricAuth = BiometricAuthService();
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum AppLanguage { en, sw }

String tx(String english, String swahili) =>
    appLanguage.value == AppLanguage.sw ? swahili : english;

String normalizePhoneInput(String value) =>
    value.trim().replaceAll(RegExp(r'[\s-]+'), '');

bool isTwelveDigitPhone(String value) =>
    RegExp(r'^\d{12}$').hasMatch(normalizePhoneInput(value));

String requireTwelveDigitPhone(String value) {
  final phone = normalizePhoneInput(value);
  if (!RegExp(r'^\d{12}$').hasMatch(phone)) {
    throw Exception(
      tx(
        'Phone number must contain exactly 12 digits, for example 255700000001.',
        'Namba ya simu lazima iwe na tarakimu 12, mfano 255700000001.',
      ),
    );
  }
  return phone;
}

List<dynamic> responseItems(dynamic value) {
  if (value is List) return value;
  if (value is Map && value['data'] is List) return value['data'] as List;
  return [];
}

int? responseTotal(dynamic value) {
  if (value is Map) return int.tryParse('${value['total'] ?? ''}');
  if (value is List) return value.length;
  return null;
}

bool responseHasMore(dynamic value) {
  if (value is! Map) return false;
  final current = int.tryParse('${value['current_page'] ?? ''}');
  final last = int.tryParse('${value['last_page'] ?? ''}');
  if (current == null || last == null) return false;
  return current < last;
}

class BiometricAuthService {
  const BiometricAuthService();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'discountlink.biometric.token';
  static const _emailKey = 'discountlink.biometric.email';
  static const _nameKey = 'discountlink.biometric.name';

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    final auth = LocalAuthentication();
    try {
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasSavedLogin() async {
    return await _storage.read(key: _tokenKey) != null;
  }

  Future<String?> savedAccountLabel() async {
    return await _storage.read(key: _nameKey) ??
        await _storage.read(key: _emailKey);
  }

  Future<bool> isEnabledFor(Map<String, dynamic> user) async {
    final token = await _storage.read(key: _tokenKey);
    final savedEmail = await _storage.read(key: _emailKey);
    final userEmail = '${user['email'] ?? ''}';

    return token != null && savedEmail != null && savedEmail == userEmail;
  }

  Future<void> enable({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: '${user['email'] ?? ''}');
    await _storage.write(key: _nameKey, value: '${user['name'] ?? ''}');
  }

  Future<void> disable() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
  }

  Future<bool> authenticate(String reason) async {
    final auth = LocalAuthentication();
    return auth.authenticate(
      localizedReason: reason,
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  }

  Future<String?> unlockToken() async {
    final available = await canUseBiometrics();
    if (!available) {
      throw Exception(
        'Biometric unlock is not available on this device. Set up fingerprint or face unlock first.',
      );
    }

    final ok = await authenticate('Unlock DiscountLink');
    if (!ok) return null;

    return _storage.read(key: _tokenKey);
  }
}

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
  StreamSubscription<String>? fcmTokenSubscription;
  StreamSubscription<RemoteMessage>? foregroundMessageSubscription;

  void signedIn(String token, Map<String, dynamic> signedUser) {
    setState(() {
      client.token = token;
      user = signedUser;
    });
    biometricAuth.isEnabledFor(signedUser).then((enabled) {
      if (enabled) {
        biometricAuth.enable(token: token, user: signedUser);
      }
    });
    registerNotifications();
  }

  Future<void> registerNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
        showForegroundNotification,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await client.post('/me/fcm-token', {'fcm_token': token});
      }
      fcmTokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          if (client.token == null) {
            return;
          }
          try {
            await client.post('/me/fcm-token', {'fcm_token': token});
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  void showForegroundNotification(RemoteMessage message) {
    if (client.token == null) return;

    // Apple displays the native foreground banner configured above. Android
    // does not, so surface the received FCM notification inside the app.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return;
    }

    final title = (message.notification?.title ?? '').trim();
    final body = (message.notification?.body ?? '').trim();
    final fallbackCode = '${message.data['delivery_code'] ?? ''}'.trim();
    final text = [
      if (title.isNotEmpty) title,
      if (body.isNotEmpty)
        body
      else if (fallbackCode.isNotEmpty)
        'Your delivery code is $fallbackCode.',
    ].join('\n');
    if (text.isEmpty) return;

    final messenger = appScaffoldMessengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
  }

  Future<void> signedOut() async {
    final tokenSubscription = fcmTokenSubscription;
    fcmTokenSubscription = null;
    try {
      await tokenSubscription?.cancel();
    } catch (_) {}
    try {
      await client.post('/me/fcm-token', {'fcm_token': null});
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
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
  void dispose() {
    fcmTokenSubscription?.cancel();
    foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, _, _) => MaterialApp(
        scaffoldMessengerKey: appScaffoldMessengerKey,
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
          upgrader: Upgrader(
            durationUntilAlertAgain: const Duration(seconds: 0),
          ),
          showIgnore: false,
          showLater: false,
          showReleaseNotes: false,
          child: showSplash
              ? SplashPage(onContinue: () => setState(() => showSplash = false))
              : user == null
              ? LoginPage(client: client, onSignedIn: signedIn)
              : HomePage(
                  client: client,
                  token: client.token ?? '',
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
    }, timeout: const Duration(minutes: 3));
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

  Future<Map<String, dynamic>> postMultipartMedia(
    String path, {
    required Map<String, String> fields,
    required List<File> images,
    required List<File> videos,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _request(() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(includeContentType: false));
      request.fields.addAll(fields);
      for (final image in images) {
        request.files.add(
          await http.MultipartFile.fromPath('product_images[]', image.path),
        );
      }
      for (final video in videos) {
        request.files.add(
          await http.MultipartFile.fromPath('product_videos[]', video.path),
        );
      }
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(minutes: 3));
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
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    late final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on SocketException {
      throw Exception(
        'We could not reach DiscountLink. Check your internet connection and try again.',
      );
    } on IOException {
      throw Exception(
        'We could not reach DiscountLink. Check your internet connection and try again.',
      );
    } on TimeoutException {
      throw Exception(
        'DiscountLink is taking too long to respond. Please try again in a moment.',
      );
    } on http.ClientException {
      throw Exception(
        'We could not connect to DiscountLink right now. Please try again shortly.',
      );
    }

    final data = decodeResponse(response);
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

  Map<String, dynamic> decodeResponse(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } on FormatException {
      if (response.statusCode >= 500) {
        throw Exception(
          'DiscountLink is temporarily unavailable. Please try again shortly.',
        );
      }
      throw Exception(
        'DiscountLink returned an unexpected response. Please try again.',
      );
    }
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
  bool biometricAvailable = false;
  bool biometricSaved = false;
  String? biometricAccountLabel;

  @override
  void initState() {
    super.initState();
    loadBiometricState();
  }

  Future<void> loadBiometricState() async {
    final available = await biometricAuth.canUseBiometrics();
    final saved = await biometricAuth.hasSavedLogin();
    final label = await biometricAuth.savedAccountLabel();
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricSaved = saved;
      biometricAccountLabel = label;
    });
  }

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
      final socialPhone = normalizePhoneInput('${auth['_phone'] ?? ''}');
      final payload = <String, dynamic>{
        if (auth['firebase_id_token'] != null)
          'firebase_id_token': auth['firebase_id_token'],
        if (auth['google_access_token'] != null)
          'google_access_token': auth['google_access_token'],
        'role': role,
        'full_name': auth['_display_name'] ?? 'Google user',
        'phone': socialPhone.isEmpty
            ? ''
            : requireTwelveDigitPhone(socialPhone),
        'address': '',
        'fcm_token': await fcmToken(),
      };
      Map<String, dynamic> response;
      try {
        response = await widget.client.post('/auth/google', payload);
      } catch (error) {
        if (!error.toString().contains(
          'accept the Terms and Conditions before signing in',
        )) {
          rethrow;
        }
        final accepted = await showGoogleTermsDialog();
        if (!accepted) return;
        response = await widget.client.post('/auth/google', {
          ...payload,
          'terms_accepted': true,
        });
      }
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

  Future<bool> showGoogleTermsDialog() async {
    var accepted = false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(tx('Terms and Conditions', 'Vigezo na Masharti')),
              content: CheckboxListTile(
                value: accepted,
                onChanged: (value) =>
                    setDialogState(() => accepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tx(
                    'I accept the Terms and Conditions',
                    'Ninakubali Vigezo na Masharti',
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(tx('Cancel', 'Ghairi')),
                ),
                FilledButton(
                  onPressed: accepted
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: Text(tx('Accept and sign in', 'Kubali na uingie')),
                ),
              ],
            ),
          ),
        ) ??
        false;
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
      final socialPhone = normalizePhoneInput(firebaseUser?.phoneNumber ?? '');
      final response = await widget.client.post('/auth/google', {
        'firebase_id_token': token,
        'role': role,
        'full_name': firebaseUser?.displayName ?? 'Apple user',
        'phone': socialPhone.isEmpty
            ? ''
            : requireTwelveDigitPhone(socialPhone),
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

  Future<void> openForgotPasswordPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(client: widget.client),
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

  Future<void> biometricLogin() async {
    setState(() => loading = true);
    try {
      final token = await biometricAuth.unlockToken();
      if (token == null || token.isEmpty) {
        throw Exception('Biometric unlock was cancelled.');
      }
      widget.client.token = token;
      final response = await widget.client.get('/me');
      widget.onSignedIn(token, response['user'] as Map<String, dynamic>);
    } catch (error) {
      widget.client.token = null;
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final minContentHeight = constraints.maxHeight > kDefaultPadding * 2
                ? constraints.maxHeight - kDefaultPadding * 2
                : 0.0;
            final contentWidth = constraints.maxWidth > 32
                ? constraints.maxWidth - 32
                : constraints.maxWidth;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(kDefaultPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: compact ? 4 : 10),
                        Image.asset(
                          'assets/images/welcome_image.png',
                          height: compact ? 112 : 145,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in with Google, or use email/phone and password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kTextColor),
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        SurfacePanel(
                          padding: EdgeInsets.all(compact ? 10 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RoleSelector(
                                value: role,
                                onChanged: (value) =>
                                    setState(() => role = value),
                              ),
                              const SizedBox(height: 12),
                              Field(
                                controller: email,
                                label: tx(
                                  'Email or phone',
                                  'Barua pepe au simu',
                                ),
                                icon: Icons.alternate_email,
                                keyboard: TextInputType.text,
                              ),
                              Field(
                                controller: password,
                                label: tx('Password', 'Nenosiri'),
                                icon: Icons.lock_outline,
                                obscure: true,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: loading
                                      ? null
                                      : openForgotPasswordPage,
                                  child: Text(
                                    tx(
                                      'Forgot password?',
                                      'Umesahau nenosiri?',
                                    ),
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: loading ? null : passwordLogin,
                                child: Text(
                                  loading
                                      ? tx('Signing in...', 'Inaingia...')
                                      : tx('Login', 'Ingia'),
                                ),
                              ),
                              if (biometricAvailable && biometricSaved) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: loading ? null : biometricLogin,
                                  icon: const Icon(Icons.fingerprint),
                                  label: Text(
                                    biometricAccountLabel == null ||
                                            biometricAccountLabel!.isEmpty
                                        ? tx(
                                            'Unlock with biometrics',
                                            'Fungua kwa alama ya kidole/uso',
                                          )
                                        : tx(
                                            'Unlock ${biometricAccountLabel!}',
                                            'Fungua ${biometricAccountLabel!}',
                                          ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: kTextColor),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: loading ? null : googleSignIn,
                                icon: const Icon(Icons.login),
                                label: Text(
                                  tx(
                                    'Continue with Google',
                                    'Endelea na Google',
                                  ),
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
                                  (defaultTargetPlatform ==
                                          TargetPlatform.iOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS)) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: loading ? null : appleSignIn,
                                  icon: const Icon(Icons.apple),
                                  label: Text(
                                    tx(
                                      'Continue with Apple',
                                      'Endelea na Apple',
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: Colors.black,
                                    side: BorderSide(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: loading ? null : openRegisterPage,
                                child: Text(
                                  tx(
                                    'No account? Register',
                                    'Huna akaunti? Jisajili',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.client});
  final ApiClient client;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  bool codeSent = false;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.post('/auth/password/forgot', {
        'email': email.text.trim(),
      });
      if (!mounted) return;
      setState(() => codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Reset code sent.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.post('/auth/password/reset', {
        'email': email.text.trim(),
        'code': code.text.trim(),
        'password': password.text,
        'password_confirmation': passwordConfirmation.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r['message'] ?? 'Password reset successful. You can now sign in.'}',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx('Reset password', 'Weka upya nenosiri'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(kDefaultPadding),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset_outlined,
                  color: kPrimaryColor,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  tx('Forgot password?', 'Umesahau nenosiri?'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your email to receive a reset code, then create a new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextColor),
                ),
                const SizedBox(height: 18),
                Field(
                  controller: email,
                  label: tx('Email', 'Barua pepe'),
                  icon: Icons.alternate_email,
                  keyboard: TextInputType.emailAddress,
                ),
                if (codeSent) ...[
                  Field(
                    controller: code,
                    label: tx('Reset code', 'Kodi ya kuweka upya'),
                    icon: Icons.pin_outlined,
                    keyboard: TextInputType.number,
                  ),
                  Field(
                    controller: password,
                    label: tx('New password', 'Nenosiri jipya'),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                  Field(
                    controller: passwordConfirmation,
                    label: tx('Confirm password', 'Thibitisha nenosiri'),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                ],
                FilledButton(
                  onPressed: loading
                      ? null
                      : codeSent
                      ? resetPassword
                      : requestCode,
                  child: Text(
                    loading
                        ? tx('Please wait...', 'Tafadhali subiri...')
                        : codeSent
                        ? tx('Reset password', 'Weka upya nenosiri')
                        : tx('Send reset code', 'Tuma kodi'),
                  ),
                ),
                if (codeSent)
                  TextButton(
                    onPressed: loading ? null : requestCode,
                    child: Text(tx('Resend code', 'Tuma tena kodi')),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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
  bool termsAccepted = false;
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
    user['_open_phone_verification'] = true;
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
    if (!termsAccepted) {
      missing.add(tx('terms and conditions', 'vigezo na masharti'));
    }
    if (missing.isNotEmpty) {
      throw Exception(
        '${tx('Complete these fields first:', 'Kamilisha taarifa hizi kwanza:')} ${missing.join(', ')}.',
      );
    }
    requireTwelveDigitPhone(phone.text);
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      requireRegistrationDetails(includeEmailPassword: true);
      final normalizedPhone = requireTwelveDigitPhone(phone.text);
      final response = await widget.client.post('/auth/register', {
        'role': role,
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': normalizedPhone,
        'nida_number': nida.text.trim(),
        'password': password.text,
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
        'terms_accepted': true,
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
      final normalizedPhone = requireTwelveDigitPhone(phone.text);
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
        'phone': normalizedPhone,
        'nida_number': nida.text.trim(),
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
        'terms_accepted': true,
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
      final normalizedPhone = requireTwelveDigitPhone(phone.text);
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
        'phone': normalizedPhone,
        'nida_number': nida.text.trim(),
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
        'terms_accepted': true,
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
                        CheckboxListTile(
                          value: termsAccepted,
                          onChanged: loading
                              ? null
                              : (value) => setState(
                                  () => termsAccepted = value ?? false,
                                ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            tx(
                              'I accept the Terms and Conditions',
                              'Ninakubali Vigezo na Masharti',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            tx(
                              'Required before creating a Discount Link account.',
                              'Inahitajika kabla ya kufungua akaunti ya Discount Link.',
                            ),
                          ),
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
    required this.token,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
  });
  final ApiClient client;
  final String token;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  int unreadChatCount = 0;
  Timer? unreadChatTimer;

  @override
  void initState() {
    super.initState();
    if (widget.user['_open_phone_verification'] == true ||
        widget.user['email_verified_at'] == null ||
        widget.user['phone_verified_at'] == null) {
      index = profileIndexForRole(widget.user['role'] as String);
    }
    loadUnreadChatCount();
    unreadChatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadUnreadChatCount(),
    );
  }

  @override
  void dispose() {
    unreadChatTimer?.cancel();
    super.dispose();
  }

  Future<void> loadUnreadChatCount() async {
    try {
      final r = await widget.client.get('/conversations');
      final conversations = responseItems(r['conversations']);
      updateUnreadChatCount(unreadCountFromConversations(conversations));
    } catch (_) {}
  }

  void updateUnreadChatCount(int count) {
    if (!mounted || count == unreadChatCount) return;
    setState(() => unreadChatCount = count);
  }

  Widget chatDestinationIcon(IconData icon) {
    final count = unreadChatCount;
    if (count <= 0) return Icon(icon);

    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: Icon(icon));
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
      if (role == 'deliverer')
        DeliveryPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      ChatPage(
        client: widget.client,
        user: widget.user,
        onUnreadCountChanged: updateUnreadChatCount,
      ),
      ProfilePage(
        client: widget.client,
        token: widget.token,
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
      NavigationDestination(
        icon: chatDestinationIcon(Icons.chat_bubble_outline),
        selectedIcon: chatDestinationIcon(Icons.chat_bubble),
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

int unreadCountFromConversations(List conversations) {
  var total = 0;
  for (final item in conversations) {
    if (item is! Map) continue;
    total += int.tryParse('${item['unread_count'] ?? 0}') ?? 0;
  }

  return total;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.client,
    required this.token,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
  });
  final ApiClient client;
  final String token;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final code = TextEditingController();
  final emailCode = TextEditingController();
  final newPhone = TextEditingController();
  bool sent = false;
  bool emailSent = false;
  bool loading = false;
  bool nameLoading = false;
  bool phoneChangeLoading = false;
  bool emailLoading = false;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool biometricLoading = false;
  bool accountDeleteLoading = false;
  String otpProvider = 'beem';
  String? firebaseVerificationId;
  String? visiblePhoneCode;
  String? localPendingPhone;

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
    name.text = '${widget.user['name'] ?? ''}'.trim();
    newPhone.text =
        '${widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'.trim();
    localPendingPhone = '${widget.user['pending_phone'] ?? ''}'.trim();
    loadProvider();
    loadBiometricState();
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    emailCode.dispose();
    newPhone.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPhone =
        '${widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'.trim();
    final previousPhone =
        '${oldWidget.user['pending_phone'] ?? oldWidget.user['phone'] ?? ''}'
            .trim();
    if (nextPhone != previousPhone && newPhone.text.trim() == previousPhone) {
      newPhone.text = nextPhone;
    }
    final nextName = '${widget.user['name'] ?? ''}'.trim();
    final previousName = '${oldWidget.user['name'] ?? ''}'.trim();
    if (nextName != previousName && name.text.trim() == previousName) {
      name.text = nextName;
    }
    localPendingPhone = '${widget.user['pending_phone'] ?? ''}'.trim();
  }

  Future<void> loadProvider() async {
    try {
      final r = await widget.client.get('/otp/provider');
      if (mounted) setState(() => otpProvider = r['provider'] as String);
    } catch (_) {}
  }

  Future<void> loadBiometricState() async {
    final available = await biometricAuth.canUseBiometrics();
    final enabled = await biometricAuth.isEnabledFor(widget.user);
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricEnabled = enabled;
    });
  }

  Future<void> setBiometricEnabled(bool value) async {
    setState(() => biometricLoading = true);
    try {
      if (value) {
        if (widget.token.isEmpty) {
          throw Exception('Sign in again before enabling biometric login.');
        }
        final ok = await biometricAuth.authenticate(
          'Confirm to enable biometric login for DiscountLink',
        );
        if (!ok) return;
        await biometricAuth.enable(token: widget.token, user: widget.user);
      } else {
        await biometricAuth.disable();
      }
      if (!mounted) return;
      setState(() => biometricEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Biometric login enabled.' : 'Biometric login disabled.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => biometricLoading = false);
    }
  }

  Future<void> deleteAccount() async {
    var confirmText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canDelete = confirmText.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Text(tx('Delete account?', 'Futa akaunti?')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tx(
                    'Your account will be deactivated and you will be signed out. You will need support to restore access.',
                    'Akaunti yako itazimwa na utatolewa. Utahitaji msaada kurejesha ufikiaji.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: tx(
                      'Type DELETE to confirm',
                      'Andika DELETE kuthibitisha',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(() {
                    confirmText = value;
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tx('Cancel', 'Ghairi')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: canDelete
                    ? () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context, true);
                      }
                    : null,
                child: Text(tx('Delete account', 'Futa akaunti')),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    setState(() => accountDeleteLoading = true);
    try {
      await widget.client.post('/me/delete', {});
      await biometricAuth.disable();
      if (!mounted) return;
      await widget.onSignOut();
      return;
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => accountDeleteLoading = false);
  }

  Future<void> saveName() async {
    final nextName = name.text.trim();
    if (nextName.isEmpty) {
      showError(
        context,
        Exception(tx('Enter your full name.', 'Weka jina lako kamili.')),
      );
      return;
    }

    setState(() => nameLoading = true);
    try {
      final r = await widget.client.put('/me', {'name': nextName});
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('Name updated.', 'Jina limesasishwa.'))),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => nameLoading = false);
    }
  }

  Future<void> sendOtp() async {
    setState(() => loading = true);
    try {
      final phone = requireTwelveDigitPhone(verificationPhone());
      if (phone.isEmpty) {
        throw Exception(
          tx('Add a phone number first.', 'Weka namba ya simu kwanza.'),
        );
      }
      if (otpProvider == 'firebase') {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone.startsWith('+') ? phone : '+$phone',
          verificationCompleted: (credential) async {
            final firebaseUser = await FirebaseAuth.instance
                .signInWithCredential(credential);
            final idToken = await firebaseUser.user?.getIdToken();
            if (idToken != null) {
              await verifyFirebaseToken(idToken, phone);
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
        if (r['phone_otp_sent'] == false) {
          throw Exception(
            r['message'] ??
                tx(
                  'OTP could not be sent. Try again shortly.',
                  'OTP haikuweza kutumwa. Jaribu tena baada ya muda.',
                ),
          );
        }
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

  Future<void> verifyFirebaseToken(
    String idToken, [
    String? verifiedPhone,
  ]) async {
    final r = await widget.client.post('/otp/verify', {
      'phone': verifiedPhone ?? requireTwelveDigitPhone(verificationPhone()),
      'firebase_id_token': idToken,
    });
    widget.onUserChanged(r['user'] as Map<String, dynamic>);
    if (mounted) {
      setState(() {
        localPendingPhone = null;
        sent = false;
        visiblePhoneCode = null;
        code.clear();
      });
    }
  }

  Future<void> verifyOtp() async {
    setState(() => loading = true);
    try {
      final phone = requireTwelveDigitPhone(verificationPhone());
      if (otpProvider == 'firebase') {
        final verificationId = firebaseVerificationId;
        if (verificationId == null) {
          throw Exception('Request the Firebase code first.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code.text.trim(),
        );
        final firebaseUser = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final idToken = await firebaseUser.user?.getIdToken();
        if (idToken == null) throw Exception('Firebase token was not issued.');
        await verifyFirebaseToken(idToken, phone);
      } else {
        final r = await widget.client.post('/otp/verify', {
          'phone': phone,
          'code': code.text.trim(),
        });
        widget.onUserChanged(r['user'] as Map<String, dynamic>);
        if (mounted) {
          setState(() {
            localPendingPhone = null;
            sent = false;
            visiblePhoneCode = null;
            code.clear();
          });
        }
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String verificationPhone() =>
      '${localPendingPhone?.isNotEmpty == true ? localPendingPhone : widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'
          .trim();

  Future<void> startPhoneChange() async {
    final phone = normalizePhoneInput(newPhone.text);
    if (phone.isEmpty) {
      showError(
        context,
        Exception(
          tx('Enter the new phone number.', 'Weka namba mpya ya simu.'),
        ),
      );
      return;
    }
    try {
      requireTwelveDigitPhone(phone);
    } catch (error) {
      showError(context, error);
      return;
    }

    setState(() => phoneChangeLoading = true);
    try {
      final r = await widget.client.put('/me', {'phone': phone});
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        localPendingPhone = phone;
        visiblePhoneCode = r['phone_code']?.toString();
        if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
          code.text = visiblePhoneCode!;
        } else {
          code.clear();
        }
        sent = r['phone_otp_sent'] == true || visiblePhoneCode != null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r['message'] ?? tx('Phone change started.', 'Mabadiliko ya simu yameanza.')}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => phoneChangeLoading = false);
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
    final pendingPhone =
        '${localPendingPhone?.isNotEmpty == true ? localPendingPhone : widget.user['pending_phone'] ?? ''}'
            .trim();
    final hasPendingPhone = pendingPhone.isNotEmpty;
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
              Field(
                controller: name,
                label: tx('Full name', 'Jina kamili'),
                icon: Icons.person_outline,
              ),
              FilledButton.icon(
                onPressed: nameLoading ? null : saveName,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  nameLoading
                      ? tx('Saving...', 'Inahifadhi...')
                      : tx('Save name', 'Hifadhi jina'),
                ),
              ),
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
              if (hasPendingPhone)
                ProfileLine(
                  icon: Icons.pending_actions_outlined,
                  title: tx('Pending phone', 'Simu inayosubiri'),
                  value: pendingPhone,
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
              const Divider(height: 24),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: biometricEnabled,
                  onChanged: biometricAvailable && !biometricLoading
                      ? setBiometricEnabled
                      : null,
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(
                    tx('Biometric login', 'Kuingia kwa alama ya kidole/uso'),
                  ),
                  subtitle: Text(
                    biometricAvailable
                        ? tx(
                            'Use fingerprint or face unlock on this device.',
                            'Tumia alama ya kidole au uso kwenye kifaa hiki.',
                          )
                        : tx(
                            'Set up fingerprint or face unlock on this device first.',
                            'Sanidi alama ya kidole au uso kwenye kifaa hiki kwanza.',
                          ),
                  ),
                ),
              ),
              if (biometricLoading) const LinearProgressIndicator(minHeight: 3),
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
                hasPendingPhone
                    ? tx('Verify new phone', 'Thibitisha simu mpya')
                    : phoneVerified
                    ? tx('Phone verified', 'Simu imethibitishwa')
                    : '${tx('Verify phone with', 'Thibitisha simu kwa')} ${otpProviderLabel(otpProvider)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Field(
                controller: newPhone,
                label: tx('New phone number', 'Namba mpya ya simu'),
                icon: Icons.phone_android_outlined,
                keyboard: TextInputType.phone,
              ),
              FilledButton.icon(
                onPressed: phoneChangeLoading ? null : startPhoneChange,
                icon: const Icon(Icons.swap_calls_outlined),
                label: Text(
                  phoneChangeLoading
                      ? tx('Sending OTP...', 'Inatuma OTP...')
                      : tx(
                          'Change phone and send OTP',
                          'Badili simu na tuma OTP',
                        ),
                ),
              ),
              const SizedBox(height: 10),
              if (!phoneVerified || hasPendingPhone) ...[
                VerificationStatusLine(
                  sent: sent,
                  visibleCode: visiblePhoneCode,
                  destination: verificationPhone(),
                  pendingText: hasPendingPhone
                      ? tx(
                          'New phone is pending. Verify it before it replaces the current number.',
                          'Simu mpya inasubiri. Ithibitishe kabla haijachukua nafasi ya namba ya sasa.',
                        )
                      : tx(
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
                const SizedBox(height: 10),
                Field(
                  controller: code,
                  label: tx(
                    'Enter phone verification code',
                    'Weka kodi ya kuthibitisha simu',
                  ),
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
              if (!phoneVerified || hasPendingPhone) ...[
                FilledButton(
                  onPressed: loading ? null : verifyOtp,
                  child: Text(
                    loading
                        ? tx('Checking...', 'Inakagua...')
                        : tx('Verify phone number', 'Thibitisha namba ya simu'),
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
                tx('Account deletion', 'Kufuta akaunti'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                tx(
                  'Deactivate this account and remove this device session.',
                  'Zima akaunti hii na ondoa kipindi cha kifaa hiki.',
                ),
                style: const TextStyle(color: kTextColor),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: accountDeleteLoading ? null : deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  accountDeleteLoading
                      ? tx('Deleting...', 'Inafuta...')
                      : tx('Delete account', 'Futa akaunti'),
                ),
              ),
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
  final money = NumberFormat('#,##0.00');
  List cart = [];
  Map<String, dynamic> serviceFee = {
    'rate': 0,
    'amount': 0,
    'currency': 'TZS',
    'enabled': false,
  };
  bool loading = true;
  bool checkingOut = false;
  bool resendingPaymentPrompt = false;
  String? checkoutPaymentStatus;
  Map<String, dynamic>? lastCheckoutPayment;
  Map<String, dynamic>? lastCheckoutPush;
  Map<String, dynamic>? lastCheckoutOrder;
  String? lastDeliveryCode;

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

  double cartUnitPrice(Map<String, dynamic> item) {
    final override = num.tryParse('${item['unit_price_override'] ?? ''}');
    if (override != null) return override.toDouble();
    final product = item['product'] as Map;
    final discount = num.tryParse('${product['discount_price'] ?? ''}');
    final price = num.tryParse('${product['price'] ?? 0}') ?? 0;

    return (discount ?? price).toDouble();
  }

  double cartDeliveryPrice(Map<String, dynamic> item) {
    final product = item['product'] as Map;
    return (num.tryParse('${product['delivery_price'] ?? 0}') ?? 0).toDouble();
  }

  double cartSubtotal() => cart.fold<double>(0, (total, item) {
    final row = item as Map<String, dynamic>;
    final quantity = (num.tryParse('${row['quantity'] ?? 1}') ?? 1).toDouble();
    return total + (cartUnitPrice(row) * quantity);
  });

  double cartDeliveryTotal() => cart.fold<double>(0, (total, item) {
    final row = item as Map<String, dynamic>;
    final quantity = (num.tryParse('${row['quantity'] ?? 1}') ?? 1).toDouble();
    return total + (cartDeliveryPrice(row) * quantity);
  });

  double serviceFeeRate() => double.tryParse('${serviceFee['rate'] ?? 0}') ?? 0;

  double serviceFeeAmount() =>
      double.tryParse('${serviceFee['amount'] ?? 0}') ??
      (cartSubtotal() * (serviceFeeRate() / 100));

  double cartGrandTotal() =>
      cartSubtotal() + cartDeliveryTotal() + serviceFeeAmount();

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.get('/cart');
      if (!mounted) return;
      setState(() {
        cart = r['items'] as List;
        serviceFee =
            (r['service_fee'] as Map?)?.cast<String, dynamic>() ??
            {'rate': 0, 'amount': 0, 'currency': 'TZS', 'enabled': false};
      });
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
    if (checkingOut || resendingPaymentPrompt) return;
    var resendAfterCheckout = false;
    setState(() {
      checkingOut = true;
      checkoutPaymentStatus = tx(
        'Creating your order and preparing ClickPesa...',
        'Inatengeneza oda na kuandaa ClickPesa...',
      );
    });
    try {
      final paymentPhone = requireTwelveDigitPhone(checkoutPhone.text);
      setState(() {
        checkoutPaymentStatus = tx(
          'Sending a USSD payment push to $paymentPhone...',
          'Inatuma ombi la malipo ya USSD kwenda $paymentPhone...',
        );
      });
      final r = await widget.client.post('/checkout', {
        'delivery_address': checkoutAddress(),
        'phone': paymentPhone,
      });
      if (!mounted) return;
      setState(() {
        checkoutPaymentStatus = tx(
          'USSD push sent. Approve it on your phone to complete payment.',
          'Ombi la USSD limetumwa. Likubali kwenye simu yako kukamilisha malipo.',
        );
      });
      final push = r['ussd_push'] as Map<String, dynamic>?;
      final payment = r['payment'] as Map<String, dynamic>?;
      setState(() {
        lastCheckoutPayment = payment;
        lastCheckoutPush = push;
        lastCheckoutOrder = (r['order'] as Map?)?.cast<String, dynamic>();
        lastDeliveryCode = '${r['delivery_code'] ?? r['delivery_code_demo']}';
      });
      final deliveryNotifications =
          (r['delivery_code_notifications'] as Map?)?.cast<String, dynamic>() ??
          {};
      final deliveryNotificationSummary = [
        if (deliveryNotifications['sms'] == true) 'SMS',
        if (deliveryNotifications['fcm'] == true) 'push notification',
      ];
      resendAfterCheckout =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(
                tx('Payment request sent', 'Ombi la malipo limetumwa'),
              ),
              content: SingleChildScrollView(
                child: Text(
                  '${tx('Order', 'Oda')}: ${r['order']['reference']}\n'
                  '${tx('Amount', 'Kiasi')}: TZS ${money.format(num.tryParse('${r['order']['grand_total'] ?? cartGrandTotal()}') ?? cartGrandTotal())}\n'
                  '${paymentRequestDetails(payment: payment, push: push, fallbackPhone: paymentPhone)}\n\n'
                  '${tx('Approve the USSD prompt on your phone. Keep this buyer delivery code:', 'Kubali ombi la USSD kwenye simu yako. Hifadhi kodi hii ya kupokea mzigo:')} '
                  '${r['delivery_code'] ?? r['delivery_code_demo']}\n\n'
                  '${deliveryNotificationSummary.isEmpty ? tx('We could not confirm an SMS or push copy; keep the code shown here.', 'Hatujaweza kuthibitisha nakala ya SMS au arifa; hifadhi kodi iliyo hapa.') : tx('A copy was also sent by ${deliveryNotificationSummary.join(' and ')}.', 'Nakala pia imetumwa kwa ${deliveryNotificationSummary.join(' na ')}.')}\n\n'
                  '${tx('Share the delivery code only after the order arrives.', 'Toa kodi ya mzigo baada tu ya kupokea oda yako.')}',
                ),
              ),
              actionsOverflowButtonSpacing: 8,
              actions: [
                if (payment?['id'] != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(
                      tx('Resend Payment request', 'Tuma tena ombi la malipo'),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('OK'),
                ),
              ],
            ),
          ) ??
          false;
      await load();
    } catch (error) {
      if (mounted) await showPaymentError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          checkingOut = false;
          checkoutPaymentStatus = null;
        });
      }
    }
    if (resendAfterCheckout && mounted) {
      await resendPaymentPrompt();
    }
  }

  Future<void> resendPaymentPrompt() async {
    if (checkingOut || resendingPaymentPrompt) return;
    final paymentId = lastCheckoutPayment?['id'];
    if (paymentId == null) return;
    setState(() {
      resendingPaymentPrompt = true;
      checkoutPaymentStatus = tx(
        'Sending the ClickPesa prompt again...',
        'Inatuma tena ombi la ClickPesa...',
      );
    });
    try {
      final r = await widget.client.post('/payments/$paymentId/ussd-push', {});
      if (!mounted) return;
      final payment =
          (r['payment'] as Map?)?.cast<String, dynamic>() ??
          lastCheckoutPayment;
      final push =
          (r['ussd_push'] as Map?)?.cast<String, dynamic>() ?? lastCheckoutPush;
      final message =
          '${r['message'] ?? tx('Payment request sent. Check your phone and approve the USSD prompt.', 'Ombi la malipo limetumwa. Angalia simu yako na ukubali ombi la USSD.')}';
      setState(() {
        lastCheckoutPayment = payment;
        lastCheckoutPush = push;
        checkoutPaymentStatus = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await showPaymentRequestSentDialog(
        payment: payment,
        push: push,
        fallbackPhone: '${payment?['phone'] ?? checkoutPhone.text}',
        message: message,
      );
    } on TimeoutException {
      if (mounted) {
        await showPaymentError(
          context,
          Exception(
            tx(
              'The payment provider took too long to respond. Check your phone for a USSD request, then tap Resend Payment request if nothing appears.',
              'Mtoa huduma ya malipo amechelewa kujibu. Angalia simu yako kwa ombi la USSD, kisha bonyeza Tuma tena ombi la malipo kama hakuna kinachoonekana.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) await showPaymentError(context, error);
    } finally {
      if (mounted) setState(() => resendingPaymentPrompt = false);
    }
  }

  String paymentRequestDetails({
    required Map<String, dynamic>? payment,
    required Map<String, dynamic>? push,
    required String fallbackPhone,
  }) {
    final initiate = (push?['initiate'] as Map?)?.cast<String, dynamic>();
    final phone = '${payment?['phone'] ?? fallbackPhone}';
    final status = '${payment?['status'] ?? push?['status'] ?? 'processing'}';
    final reference =
        '${push?['reference'] ?? payment?['provider_reference'] ?? push?['orderReference'] ?? '-'}';
    final channel = '${initiate?['channel'] ?? push?['channel'] ?? ''}'.trim();

    return [
      '${tx('Phone', 'Simu')}: $phone',
      '${tx('Payment status', 'Hali ya malipo')}: $status',
      '${tx('Reference', 'Kumbukumbu')}: $reference',
      if (channel.isNotEmpty) '${tx('Channel', 'Mtandao')}: $channel',
    ].join('\n');
  }

  Future<void> showPaymentRequestSentDialog({
    required Map<String, dynamic>? payment,
    required Map<String, dynamic>? push,
    required String fallbackPhone,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tx('Payment request sent', 'Ombi la malipo limetumwa')),
        content: SingleChildScrollView(
          child: Text(
            '$message\n\n'
            '${paymentRequestDetails(payment: payment, push: push, fallbackPhone: fallbackPhone)}\n\n'
            '${tx('Approve the USSD prompt on the payment phone. If no prompt appears, wait a moment and use Resend Payment request.', 'Kubali ombi la USSD kwenye simu ya malipo. Kama ombi halionekani, subiri kidogo kisha tumia Tuma tena ombi la malipo.')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('OK', 'Sawa')),
          ),
        ],
      ),
    );
  }

  Future<void> showPaymentError(BuildContext context, Object error) async {
    final message = error.toString().replaceFirst('Exception: ', '');
    final mPesaInactive = message.toLowerCase().contains(
      'm-pesa payment method is not active',
    );
    final providerNote = mPesaInactive
        ? '${tx('M-Pesa collections must be activated on the ClickPesa account before Vodacom numbers can receive the request.', 'Malipo ya M-Pesa lazima yawashwe kwenye akaunti ya ClickPesa kabla namba za Vodacom hazijapokea ombi.')}\n\n'
        : '';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          tx('Payment request was not sent', 'Ombi la malipo halikutumwa'),
        ),
        content: SingleChildScrollView(
          child: Text(
            '$message\n\n'
            '$providerNote'
            '${tx('Your cart is still saved. Check that the payment phone has exactly 12 digits, then try Resend Payment request after the provider issue is resolved.', 'Kikapu chako bado kimehifadhiwa. Hakiki namba ya malipo iwe na tarakimu 12, kisha jaribu Tuma tena ombi la malipo baada ya tatizo la mtoa huduma kutatuliwa.')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('OK', 'Sawa')),
          ),
        ],
      ),
    );
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
                    title: tx('Payment summary', 'Muhtasari wa malipo'),
                  ),
                  const SizedBox(height: 8),
                  PaymentSummaryRow(
                    label: tx('Products', 'Bidhaa'),
                    value: 'TZS ${money.format(cartSubtotal())}',
                  ),
                  PaymentSummaryRow(
                    label: tx('Delivery', 'Usafiri'),
                    value: 'TZS ${money.format(cartDeliveryTotal())}',
                  ),
                  PaymentSummaryRow(
                    label:
                        '${tx('Service fee', 'Ada ya huduma')} (${money.format(serviceFeeRate())}%)',
                    value: 'TZS ${money.format(serviceFeeAmount())}',
                  ),
                  const Divider(height: 20),
                  PaymentSummaryRow(
                    label: tx('Total to pay', 'Jumla ya kulipa'),
                    value: 'TZS ${money.format(cartGrandTotal())}',
                    strong: true,
                  ),
                  const SizedBox(height: 10),
                  PaymentInfoBox(
                    icon: Icons.phone_android_outlined,
                    text: tx(
                      'ClickPesa sends a USSD prompt to the payment phone below. Approve the prompt on that phone to complete payment.',
                      'ClickPesa hutuma ombi la USSD kwenye simu ya malipo hapo chini. Kubali ombi hilo kwenye simu hiyo kukamilisha malipo.',
                    ),
                  ),
                  if (checkoutPaymentStatus != null) ...[
                    const SizedBox(height: 10),
                    PaymentInfoBox(
                      icon: Icons.sync_outlined,
                      text: checkoutPaymentStatus!,
                      active: true,
                    ),
                  ],
                  if (lastCheckoutPayment?['id'] != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: checkingOut || resendingPaymentPrompt
                            ? null
                            : resendPaymentPrompt,
                        icon: resendingPaymentPrompt
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_outlined),
                        label: Text(
                          resendingPaymentPrompt
                              ? tx(
                                  'Sending payment request...',
                                  'Inatuma ombi la malipo...',
                                )
                              : tx(
                                  'Resend Payment request',
                                  'Tuma tena ombi la malipo',
                                ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (lastCheckoutOrder != null || lastDeliveryCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${tx('Last order', 'Oda ya mwisho')}: ${lastCheckoutOrder?['reference'] ?? '-'}'
                          '${lastDeliveryCode == null ? '' : '\n${tx('Delivery code', 'Kodi ya mzigo')}: $lastDeliveryCode'}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: kTextColor),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
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
                    onPressed:
                        cart.isEmpty ||
                            loading ||
                            checkingOut ||
                            resendingPaymentPrompt
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
  bool loadingMoreProducts = false;
  int productPage = 1;
  int? productTotal;
  bool productHasMore = false;

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

  Future<void> load({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMoreProducts = true;
      } else {
        loadingProducts = true;
        loadingCart = true;
        productPage = 1;
      }
    });
    final page = append ? productPage + 1 : 1;
    final query = <String, String>{'page': '$page', 'per_page': '20'};
    if (search.text.trim().isNotEmpty) query['q'] = search.text.trim();
    if (selectedCategory != null) query['category'] = selectedCategory!;
    try {
      final r = await widget.client.get('/products', query);
      final c = append ? null : await widget.client.get('/cart');
      final productResponse = r['products'];
      final nextProducts = responseItems(productResponse);
      if (!mounted) return;
      setState(() {
        products = append ? [...products, ...nextProducts] : nextProducts;
        productPage = page;
        productTotal = responseTotal(productResponse);
        productHasMore = responseHasMore(productResponse);
        if (c != null) cart = c['items'] as List;
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loadingProducts = false;
          loadingCart = false;
          loadingMoreProducts = false;
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
        products = responseItems(r['products']);
        productTotal = products.length;
        productHasMore = false;
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

  Future<void> shareProductDownload(Map<String, dynamic> product) async {
    final productName = '${product['name'] ?? 'this product'}'.trim();
    final shopName = '${product['shop']?['name'] ?? ''}'.trim();
    final total = num.tryParse('${product['auto_total'] ?? product['price']}');
    final priceLine = total == null
        ? ''
        : '\n${tx('Price', 'Bei')}: TZS ${money.format(total)}';
    final shopLine = shopName.isEmpty
        ? ''
        : '\n${tx('Shop', 'Duka')}: $shopName';
    final message = tx(
      'I found $productName on Vigour Deals.$shopLine$priceLine\n\nDownload the app to view and buy this product:\nAndroid: $playStoreUrl\niPhone: $appStoreUrl',
      'Nimepata $productName kwenye Vigour Deals.$shopLine$priceLine\n\nPakua app kuangalia na kununua bidhaa hii:\nAndroid: $playStoreUrl\niPhone: $appStoreUrl',
    );

    await SharePlus.instance.share(
      ShareParams(text: message, subject: 'View $productName on Vigour Deals'),
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
          if (!loadingProducts && productTotal != null) ...[
            const SizedBox(height: 4),
            Text(
              tx(
                'Showing ${products.length} of $productTotal products',
                'Inaonyesha ${products.length} kati ya bidhaa $productTotal',
              ),
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ],
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
                childAspectRatio: 0.58,
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
                  onShare: () => shareProductDownload(product),
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
          if (!loadingProducts && productHasMore && !imageSearchActive) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loadingMoreProducts ? null : () => load(append: true),
              icon: loadingMoreProducts
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                loadingMoreProducts
                    ? tx('Loading...', 'Inapakia...')
                    : tx('Load more', 'Pakia zaidi'),
              ),
            ),
          ],
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
  bool loadingMore = false;
  int orderPage = 1;
  int? orderTotal;
  bool orderHasMore = false;
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

  Future<void> load({
    bool showLoading = false,
    bool silent = false,
    bool append = false,
  }) async {
    if (refreshing || loadingMore) return;
    if (showLoading && mounted) {
      setState(() => loading = true);
    } else if (append && mounted) {
      setState(() => loadingMore = true);
    }
    refreshing = !append;
    final page = append ? orderPage + 1 : 1;
    try {
      final r = await widget.client.get('/orders/active', {
        'page': '$page',
        'per_page': '20',
      });
      final orderResponse = r['orders'];
      final nextOrders = responseItems(orderResponse);
      if (mounted) {
        setState(() {
          orders = append ? [...orders, ...nextOrders] : nextOrders;
          orderPage = page;
          orderTotal = responseTotal(orderResponse);
          orderHasMore = responseHasMore(orderResponse);
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
      if (mounted) setState(() => loadingMore = false);
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
        if (!loading && orderTotal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Showing ${orders.length} of $orderTotal orders',
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
        if (!loading && orderHasMore)
          OutlinedButton.icon(
            onPressed: loadingMore ? null : () => load(append: true),
            icon: loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(loadingMore ? 'Loading...' : 'Load more orders'),
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
  static const int campaignPageSize = 5;
  static const int productPageSize = 5;

  final shopName = TextEditingController();
  final address = TextEditingController();
  final shopRegistrationPhone = TextEditingController();
  final productName = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final discount = TextEditingController();
  final delivery = TextEditingController();
  final stock = TextEditingController(text: '10');
  final delivererName = TextEditingController();
  final delivererPhone = TextEditingController();
  final campaignPhone = TextEditingController();
  final money = NumberFormat('#,##0.00');
  final selectedCategories = <String>{'Electronics'};
  List<String> shopCategories = defaultShopCategories;
  final picker = ImagePicker();
  List<XFile> selectedProductImages = [];
  List<XFile> selectedProductVideos = [];
  List shops = [];
  List campaigns = [];
  Map<String, dynamic> campaignPricing = {};
  Map<String, dynamic> registrationFee = {
    'amount': 0,
    'currency': 'TZS',
    'enabled': false,
  };
  List delivererInvitations = [];
  int? selectedShopId;
  int? editingShopId;
  int? editingProductId;
  _ShopEditDraft? shopDraft;
  _ProductEditDraft? productDraft;
  List<XFile> replacementProductImages = [];
  List<XFile> replacementProductVideos = [];
  bool clearReplacementProductVideos = false;
  TimeOfDay openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closingTime = const TimeOfDay(hour: 20, minute: 0);
  int? campaignProductId;
  String campaignChannel = 'fcm';
  bool loadingShops = true;
  bool loadingMoreShops = false;
  bool invitingDeliverer = false;
  bool loadingCampaigns = true;
  bool creatingCampaign = false;
  bool creatingShop = false;
  int? resendingCampaignPaymentId;
  int? resendingShopPaymentId;
  int? deletingShopId;
  int shopPage = 1;
  int? shopTotal;
  bool shopHasMore = false;
  int campaignPage = 1;
  int? campaignTotal;
  bool campaignHasMore = false;
  final Map<int, int> productPageByShop = {};

  bool get sellerUssdBusy =>
      creatingCampaign ||
      creatingShop ||
      resendingCampaignPaymentId != null ||
      resendingShopPaymentId != null;

  @override
  void initState() {
    super.initState();
    address.text = widget.user['address'] ?? '';
    shopRegistrationPhone.text = widget.user['phone'] ?? '';
    campaignPhone.text = widget.user['phone'] ?? '';
    loadCategories();
    load();
    loadCampaigns();
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

  Future<void> load({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMoreShops = true;
      } else {
        loadingShops = true;
      }
    });
    final page = append ? shopPage + 1 : 1;
    try {
      final r = await widget.client.get('/seller/shops', {
        'page': '$page',
        'per_page': '20',
      });
      final shopResponse = r['shops'];
      final nextShops = responseItems(shopResponse);
      if (!mounted) return;
      setState(() {
        shops = append ? [...shops, ...nextShops] : nextShops;
        shopPage = page;
        shopTotal = responseTotal(shopResponse);
        shopHasMore = responseHasMore(shopResponse);
        registrationFee =
            (r['registration_fee'] as Map?)?.cast<String, dynamic>() ??
            {'amount': 0, 'currency': 'TZS', 'enabled': false};
        delivererInvitations = (r['deliverer_invitations'] as List?) ?? [];
        if (shops.isNotEmpty) {
          selectedShopId ??= shops.first['id'] as int;
          if (!shops.any((shop) => shop['id'] == selectedShopId)) {
            selectedShopId = shops.first['id'] as int;
          }
        } else {
          selectedShopId = null;
        }
        clampProductPages();
        final products = sellerProducts();
        if (products.isNotEmpty) {
          campaignProductId ??= products.first['id'] as int?;
          if (!products.any((product) => product['id'] == campaignProductId)) {
            campaignProductId = products.first['id'] as int?;
          }
        } else {
          campaignProductId = null;
        }
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loadingShops = false;
          loadingMoreShops = false;
        });
      }
    }
  }

  String apiTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  TimeOfDay parseApiTime(String? value, TimeOfDay fallback) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> pickShopTime({required bool opening}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: opening ? openingTime : closingTime,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        openingTime = selected;
      } else {
        closingTime = selected;
      }
    });
  }

  Future<void> pickDraftShopTime({required bool opening}) async {
    final draft = shopDraft;
    if (draft == null) return;
    final current = parseApiTime(
      opening ? draft.openingTime : draft.closingTime,
      opening
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 20, minute: 0),
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        draft.openingTime = apiTime(selected);
      } else {
        draft.closingTime = apiTime(selected);
      }
    });
  }

  Widget compactScheduleButton({
    required Key key,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    );
  }

  Widget responsiveScheduleButtons({
    required Key openingKey,
    required Key closingKey,
    required VoidCallback onOpeningPressed,
    required VoidCallback onClosingPressed,
    required String openingLabel,
    required String closingLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: compactScheduleButton(
            key: openingKey,
            onPressed: onOpeningPressed,
            icon: Icons.storefront_outlined,
            label: openingLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: compactScheduleButton(
            key: closingKey,
            onPressed: onClosingPressed,
            icon: Icons.nightlight_outlined,
            label: closingLabel,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> sellerProducts() {
    return [
      for (final shop in shops)
        for (final product in ((shop['products'] as List?) ?? []))
          if (product is Map)
            Map<String, dynamic>.from(product)
              ..putIfAbsent('shop_name', () => shop['name']),
    ];
  }

  List<dynamic> productsForShop(dynamic shop) {
    if (shop is! Map) return const <dynamic>[];
    return (shop['products'] as List?) ?? const <dynamic>[];
  }

  int? idForShop(dynamic shop) {
    if (shop is! Map) return null;
    return int.tryParse('${shop['id'] ?? ''}');
  }

  int productPageCount(dynamic shop) {
    final count = productsForShop(shop).length;
    return count == 0 ? 1 : ((count - 1) ~/ productPageSize) + 1;
  }

  int productPageForShop(dynamic shop) {
    final shopId = idForShop(shop);
    var page = shopId == null ? 1 : (productPageByShop[shopId] ?? 1);
    final lastPage = productPageCount(shop);
    if (page < 1) page = 1;
    if (page > lastPage) page = lastPage;
    return page;
  }

  List<dynamic> visibleProductsForShop(dynamic shop) {
    final products = productsForShop(shop);
    final page = productPageForShop(shop);
    final start = (page - 1) * productPageSize;
    final end = start + productPageSize < products.length
        ? start + productPageSize
        : products.length;
    return products.sublist(start, end);
  }

  void clampProductPages() {
    final loadedShopIds = <int>{};
    for (final shop in shops) {
      final shopId = idForShop(shop);
      if (shopId == null) continue;
      loadedShopIds.add(shopId);
      productPageByShop[shopId] = productPageForShop(shop);
    }
    productPageByShop.removeWhere(
      (shopId, _) => !loadedShopIds.contains(shopId),
    );
  }

  void changeProductPage(dynamic shop, int requestedPage) {
    final shopId = idForShop(shop);
    if (shopId == null) return;
    var nextPage = requestedPage;
    final lastPage = productPageCount(shop);
    if (nextPage < 1) nextPage = 1;
    if (nextPage > lastPage) nextPage = lastPage;
    setState(() => productPageByShop[shopId] = nextPage);
  }

  String productPageLabel(dynamic shop) {
    final count = productsForShop(shop).length;
    final page = productPageForShop(shop);
    final first = count == 0 ? 0 : ((page - 1) * productPageSize) + 1;
    final last = count == 0
        ? 0
        : (first + productPageSize - 1 < count
              ? first + productPageSize - 1
              : count);
    return 'Showing $first–$last of $count products';
  }

  String campaignPageLabel() {
    final first = campaigns.isEmpty
        ? 0
        : ((campaignPage - 1) * campaignPageSize) + 1;
    final last = campaigns.isEmpty ? 0 : first + campaigns.length - 1;
    final total = campaignTotal;
    return total == null
        ? 'Showing $first–$last campaigns'
        : 'Showing $first–$last of $total campaigns';
  }

  Future<Map<String, dynamic>> fetchCampaignPage(int page) {
    return widget.client.get('/seller/campaigns', {
      'page': '$page',
      'per_page': '$campaignPageSize',
    });
  }

  Future<void> loadCampaigns({int page = 1}) async {
    var requestedPage = page < 1 ? 1 : page;
    setState(() {
      loadingCampaigns = true;
      campaignPricing = {};
    });
    try {
      var response = await fetchCampaignPage(requestedPage);
      var campaignResponse = response['campaigns'];
      if (campaignResponse is Map) {
        final parsedLastPage = int.tryParse(
          '${campaignResponse['last_page'] ?? ''}',
        );
        final lastPage = parsedLastPage != null && parsedLastPage > 0
            ? parsedLastPage
            : 1;
        if (requestedPage > lastPage) {
          requestedPage = lastPage;
          response = await fetchCampaignPage(requestedPage);
          campaignResponse = response['campaigns'];
        }
      }
      if (!mounted) return;
      setState(() {
        final returnedPage = campaignResponse is Map
            ? int.tryParse('${campaignResponse['current_page'] ?? ''}')
            : null;
        campaigns = responseItems(campaignResponse);
        campaignPage = returnedPage != null && returnedPage > 0
            ? returnedPage
            : requestedPage;
        campaignTotal = responseTotal(campaignResponse);
        campaignHasMore = responseHasMore(campaignResponse);
        campaignPricing =
            (response['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loadingCampaigns = false);
    }
  }

  Map<String, dynamic> selectedCampaignPricing() {
    return (campaignPricing[campaignChannel] as Map?)
            ?.cast<String, dynamic>() ??
        {};
  }

  bool campaignQuoteIsReady() {
    if (loadingCampaigns) return false;
    final pricing = selectedCampaignPricing();
    final unitPrice = num.tryParse('${pricing['unit_price'] ?? ''}');
    final recipientCount = int.tryParse(
      '${pricing['eligible_recipient_count'] ?? ''}',
    );
    final estimatedTotal = num.tryParse('${pricing['estimated_total'] ?? ''}');

    return unitPrice != null &&
        unitPrice >= 0 &&
        recipientCount != null &&
        recipientCount > 0 &&
        estimatedTotal != null &&
        estimatedTotal >= 0;
  }

  Future<void> createCampaign() async {
    if (sellerUssdBusy) return;
    final productId = campaignProductId;
    if (productId == null) {
      showError(context, Exception('Choose a product to promote.'));
      return;
    }
    if (!campaignQuoteIsReady()) {
      showError(
        context,
        Exception(
          loadingCampaigns
              ? 'Wait for the latest campaign price before continuing.'
              : 'A live campaign price and eligible audience are required. Refresh and try again.',
        ),
      );
      return;
    }
    final pricing = selectedCampaignPricing();
    final recipientCount = pricing['eligible_recipient_count'] ?? 0;
    final estimated = num.tryParse('${pricing['estimated_total'] ?? 0}') ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm product campaign'),
        content: Text(
          'DiscountLink will generate the campaign message and send it to $recipientCount eligible users through ${campaignChannel.toUpperCase()}.\n\nEstimated cost: TZS ${money.format(estimated)}. The final recipient count and price are locked when the campaign is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(estimated > 0 ? 'Create and pay' : 'Create campaign'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (sellerUssdBusy) return;

    setState(() => creatingCampaign = true);
    try {
      final response = await widget.client.post('/seller/campaigns', {
        'product_id': productId,
        'channel': campaignChannel,
        if (campaignPhone.text.trim().isNotEmpty)
          'payment_phone': requireTwelveDigitPhone(campaignPhone.text),
      });
      await loadCampaigns(page: 1);
      if (!mounted) return;
      final payment = response['payment'] as Map?;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(payment == null ? 'Campaign queued' : 'Payment sent'),
          content: Text(
            '${response['message'] ?? 'Campaign created.'}'
            '${payment == null ? '' : '\n\nApprove the ClickPesa USSD request on ${payment['phone'] ?? campaignPhone.text}. The campaign starts only after payment is confirmed.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => creatingCampaign = false);
    }
  }

  Future<void> resendCampaignPayment(Map<String, dynamic> campaign) async {
    if (sellerUssdBusy) return;
    final paymentId = int.tryParse(
      '${(campaign['payment'] as Map?)?['id'] ?? ''}',
    );
    if (paymentId == null) return;
    setState(() => resendingCampaignPaymentId = paymentId);
    try {
      final response = await widget.client.post(
        '/seller/campaign-payments/$paymentId/ussd-push',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${response['message'] ?? 'Payment request sent.'}'),
        ),
      );
      await loadCampaigns(page: campaignPage);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && resendingCampaignPaymentId == paymentId) {
        setState(() => resendingCampaignPaymentId = null);
      }
    }
  }

  Future<void> pickProductImages() async {
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;
    if (images.length != 3) {
      if (mounted) {
        showError(context, Exception('Choose exactly 3 product images.'));
      }
      return;
    }
    setState(() => selectedProductImages = images.take(3).toList());
  }

  Future<void> pickProductVideo() async {
    if (selectedProductVideos.length >= 2) return;
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null || !mounted) return;
    setState(() => selectedProductVideos = [...selectedProductVideos, video]);
  }

  List<String> productImagePaths() {
    return selectedProductImages.map((image) => image.path).toList();
  }

  Map<String, dynamic>? selectedShop() {
    for (final shop in shops) {
      if (shop is Map<String, dynamic> && shop['id'] == selectedShopId) {
        return shop;
      }
    }
    return null;
  }

  double registrationFeeAmount() =>
      double.tryParse('${registrationFee['amount'] ?? 0}') ?? 0;

  bool registrationFeeEnabled() =>
      registrationFee['enabled'] == true || registrationFeeAmount() > 0;

  String shopRegistrationStatus(Map<String, dynamic> shop) {
    final status = '${shop['registration_fee_status'] ?? 'waived'}';
    if (shop['is_active'] == true && status == 'paid') {
      return 'Registration paid';
    }
    if (shop['is_active'] == true && status == 'waived') {
      return 'Registration fee waived';
    }
    if (status == 'processing') return 'Waiting for ClickPesa confirmation';
    if (status == 'failed') return 'Registration fee push failed';
    return 'Registration fee pending';
  }

  int? shopRegistrationPaymentId(Map<String, dynamic> shop) {
    final payment =
        shop['registration_fee_payment'] ?? shop['registrationFeePayment'];
    final value = payment is Map
        ? payment['id']
        : shop['registration_fee_payment_id'];
    return int.tryParse('${value ?? ''}');
  }

  bool canRetryShopRegistration(Map<String, dynamic> shop) {
    if (shop['is_active'] == true || shopRegistrationPaymentId(shop) == null) {
      return false;
    }
    return const {
      'pending',
      'processing',
      'failed',
      'payment_failed',
    }.contains('${shop['registration_fee_status'] ?? ''}');
  }

  Future<void> resendShopRegistrationPayment(Map<String, dynamic> shop) async {
    if (sellerUssdBusy) return;
    final paymentId = shopRegistrationPaymentId(shop);
    if (paymentId == null) return;
    setState(() => resendingShopPaymentId = paymentId);
    try {
      final response = await widget.client.post(
        '/seller/shop-payments/$paymentId/ussd-push',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? 'Registration payment request sent.'}',
          ),
        ),
      );
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && resendingShopPaymentId == paymentId) {
        setState(() => resendingShopPaymentId = null);
      }
    }
  }

  Future<void> deleteShop(Map<String, dynamic> shop) async {
    if (deletingShopId != null || sellerUssdBusy) return;
    final shopId = int.tryParse('${shop['id'] ?? ''}');
    if (shopId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shop?'),
        content: Text(
          '${shop['name'] ?? 'This shop'} and its products will no longer be visible to buyers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete shop'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || deletingShopId != null) return;

    setState(() => deletingShopId = shopId);
    try {
      final response = await widget.client.delete('/shops/$shopId');
      if (!mounted) return;
      if (editingShopId == shopId) cancelShopEdit();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response['message'] ?? 'Shop deleted.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted && deletingShopId == shopId) {
        setState(() => deletingShopId = null);
      }
    }
  }

  Future<void> saveShop() async {
    if (sellerUssdBusy) return;
    setState(() => creatingShop = true);
    try {
      final registrationPaymentPhone = registrationFeeEnabled()
          ? requireTwelveDigitPhone(shopRegistrationPhone.text)
          : null;
      final r = await widget.client.post('/shops', {
        'name': shopName.text,
        'category': selectedCategories.first,
        'categories': selectedCategories.toList(),
        'address': address.text,
        'opening_time': apiTime(openingTime),
        'closing_time': apiTime(closingTime),
        'timezone': 'Africa/Dar_es_Salaam',
        if (registrationPaymentPhone != null)
          'registration_payment_phone': registrationPaymentPhone,
      });
      shopName.clear();
      await load();
      if (!mounted) return;
      final payment = r['payment'] as Map<String, dynamic>?;
      if (payment != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration fee push sent'),
            content: Text(
              'Approve the ClickPesa USSD prompt on ${payment['phone'] ?? shopRegistrationPhone.text}.\n\n'
              'Amount: TZS ${money.format(double.tryParse('${payment['amount'] ?? registrationFeeAmount()}') ?? registrationFeeAmount())}\n'
              'Shop activates after payment confirmation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${r['message'] ?? 'Shop created.'}')),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
      await load();
    } finally {
      if (mounted) setState(() => creatingShop = false);
    }
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
        openingTime: '${shop['opening_time'] ?? '08:00'}',
        closingTime: '${shop['closing_time'] ?? '20:00'}',
      );
    });
  }

  void startEditProduct(Map<String, dynamic> product) {
    productDraft?.dispose();
    setState(() {
      editingProductId = product['id'] as int?;
      replacementProductImages = [];
      replacementProductVideos = [];
      clearReplacementProductVideos = false;
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
      replacementProductVideos = [];
      clearReplacementProductVideos = false;
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
        'opening_time': draft.openingTime,
        'closing_time': draft.closingTime,
        'timezone': 'Africa/Dar_es_Salaam',
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
    if (images.length != 3) {
      if (mounted) {
        showError(context, Exception('Choose exactly 3 replacement images.'));
      }
      return;
    }
    setState(() => replacementProductImages = images.take(3).toList());
  }

  Future<void> pickReplacementProductVideo() async {
    if (replacementProductVideos.length >= 2) return;
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null || !mounted) return;
    setState(
      () => replacementProductVideos = [...replacementProductVideos, video],
    );
  }

  Future<void> saveProductEdit(Map<String, dynamic> product) async {
    final draft = productDraft;
    if (draft == null) return;
    try {
      if (replacementProductImages.isNotEmpty ||
          replacementProductVideos.isNotEmpty ||
          clearReplacementProductVideos) {
        if (replacementProductImages.isNotEmpty &&
            replacementProductImages.length != 3) {
          throw Exception('Choose exactly 3 product images.');
        }
        await widget.client.postMultipartMedia(
          '/products/${product['id']}',
          fields: {
            'name': draft.name.text.trim(),
            'description': draft.description.text.trim(),
            'price': draft.price.text,
            'discount_percent': draft.discount.text,
            'delivery_price': draft.delivery.text,
            'stock': draft.stock.text,
            if (clearReplacementProductVideos) 'clear_videos': '1',
          },
          images: replacementProductImages
              .map((image) => File(image.path))
              .toList(),
          videos: replacementProductVideos
              .map((video) => File(video.path))
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
    final phone = normalizePhoneInput(delivererPhone.text);
    if (phone.isEmpty) {
      showError(context, Exception('Enter the deliverer phone number.'));
      return;
    }
    try {
      requireTwelveDigitPhone(phone);
    } catch (error) {
      showError(context, error);
      return;
    }

    setState(() => invitingDeliverer = true);
    try {
      final r = await widget.client.post('/seller/deliverer-invitations', {
        'name': delivererName.text.trim(),
        'phone': phone,
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
    shopRegistrationPhone.dispose();
    productName.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
    delivererName.dispose();
    delivererPhone.dispose();
    campaignPhone.dispose();
    shopDraft?.dispose();
    productDraft?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSelectedShop = selectedShop();
    final selectedShopCanPublish =
        activeSelectedShop == null || activeSelectedShop['is_active'] == true;

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
              responsiveScheduleButtons(
                openingKey: const ValueKey('shop-opening-time'),
                closingKey: const ValueKey('shop-closing-time'),
                onOpeningPressed: () => pickShopTime(opening: true),
                onClosingPressed: () => pickShopTime(opening: false),
                openingLabel: 'Opens ${openingTime.format(context)}',
                closingLabel: 'Closes ${closingTime.format(context)}',
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Times use the shop timezone (Africa/Dar_es_Salaam). Overnight hours are supported.',
                  style: TextStyle(color: kTextColor, fontSize: 12),
                ),
              ),
              PaymentInfoBox(
                icon: registrationFeeEnabled()
                    ? Icons.payments_outlined
                    : Icons.check_circle_outline,
                active: registrationFeeEnabled(),
                text: registrationFeeEnabled()
                    ? 'New shops pay TZS ${money.format(registrationFeeAmount())} via ClickPesa USSD before they become active. The prompt is sent to the payment phone below.'
                    : 'Shop registration fee is currently waived by the backend.',
              ),
              const SizedBox(height: 12),
              if (registrationFeeEnabled())
                Field(
                  controller: shopRegistrationPhone,
                  label: 'ClickPesa payment phone',
                  icon: Icons.phone_android_outlined,
                  keyboard: TextInputType.phone,
                ),
              FilledButton.icon(
                key: const ValueKey('save-shop'),
                onPressed: sellerUssdBusy ? null : saveShop,
                icon: creatingShop
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business),
                label: Text(
                  creatingShop
                      ? registrationFeeEnabled()
                            ? 'Sending registration payment...'
                            : 'Saving shop...'
                      : registrationFeeEnabled()
                      ? 'Save shop and send fee push'
                      : 'Save shop',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(title: 'Product campaigns'),
              const SizedBox(height: 6),
              const Text(
                'Promote one of your products to all currently eligible users. DiscountLink creates the message; sellers cannot edit campaign copy.',
                style: TextStyle(color: kTextColor, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (sellerProducts().isEmpty)
                const PaymentInfoBox(
                  icon: Icons.inventory_2_outlined,
                  text: 'Publish an active product before creating a campaign.',
                )
              else ...[
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: campaignProductId,
                  items: [
                    for (final product in sellerProducts())
                      DropdownMenuItem(
                        value: product['id'] as int,
                        child: Text(
                          '${product['name']} · ${product['shop_name'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => campaignProductId = value),
                  decoration: const InputDecoration(labelText: 'Product'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'fcm',
                      icon: Icon(Icons.notifications_active_outlined),
                      label: Text('FCM'),
                    ),
                    ButtonSegment(
                      value: 'sms',
                      icon: Icon(Icons.sms_outlined),
                      label: Text('SMS'),
                    ),
                  ],
                  selected: {campaignChannel},
                  onSelectionChanged: (selection) =>
                      setState(() => campaignChannel = selection.first),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final pricing = selectedCampaignPricing();
                    final unit =
                        num.tryParse('${pricing['unit_price'] ?? 0}') ?? 0;
                    final count = pricing['eligible_recipient_count'] ?? 0;
                    final total =
                        num.tryParse('${pricing['estimated_total'] ?? 0}') ?? 0;
                    return PaymentInfoBox(
                      icon: Icons.campaign_outlined,
                      active: total > 0,
                      text:
                          '${campaignChannel.toUpperCase()}: TZS ${money.format(unit)} per recipient · $count eligible users · estimated TZS ${money.format(total)}',
                    );
                  },
                ),
                const SizedBox(height: 12),
                if ((num.tryParse(
                          '${selectedCampaignPricing()['estimated_total'] ?? 0}',
                        ) ??
                        0) >
                    0)
                  Field(
                    controller: campaignPhone,
                    label: 'ClickPesa payment phone',
                    icon: Icons.phone_android_outlined,
                    keyboard: TextInputType.phone,
                  ),
                FilledButton.icon(
                  onPressed: sellerUssdBusy || !campaignQuoteIsReady()
                      ? null
                      : createCampaign,
                  icon: creatingCampaign
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    creatingCampaign
                        ? 'Creating campaign...'
                        : loadingCampaigns
                        ? 'Loading campaign price...'
                        : !campaignQuoteIsReady()
                        ? 'Campaign unavailable'
                        : 'Create campaign',
                  ),
                ),
              ],
              if (loadingCampaigns) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ] else if (campaigns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recent campaigns',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final rawCampaign in campaigns)
                  Builder(
                    builder: (context) {
                      final campaign = (rawCampaign as Map)
                          .cast<String, dynamic>();
                      final status = '${campaign['status'] ?? 'pending'}';
                      final pendingPayment =
                          status == 'pending_payment' ||
                          status == 'payment_failed';
                      final paymentId = int.tryParse(
                        '${(campaign['payment'] as Map?)?['id'] ?? ''}',
                      );
                      final isResending =
                          paymentId != null &&
                          resendingCampaignPaymentId == paymentId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: kPrimaryLightColor,
                          child: Icon(
                            campaign['channel'] == 'sms'
                                ? Icons.sms_outlined
                                : Icons.notifications_outlined,
                            color: kPrimaryColor,
                          ),
                        ),
                        title: Text(
                          '${campaign['product']?['name'] ?? 'Product campaign'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${campaign['sent_count'] ?? 0}/${campaign['recipient_count'] ?? 0} sent · $status · TZS ${money.format(num.tryParse('${campaign['total_cost'] ?? 0}') ?? 0)}',
                        ),
                        trailing: pendingPayment && paymentId != null
                            ? IconButton(
                                key: ValueKey(
                                  'campaign-${campaign['id']}-payment-resend',
                                ),
                                tooltip: isResending
                                    ? 'Sending payment request'
                                    : 'Resend payment request',
                                onPressed: sellerUssdBusy
                                    ? null
                                    : () => resendCampaignPayment(campaign),
                                icon: isResending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_outlined),
                              )
                            : null,
                      );
                    },
                  ),
                if (campaignPage > 1 || campaignHasMore) ...[
                  const SizedBox(height: 8),
                  _SellerPaginationControls(
                    label: campaignPageLabel(),
                    previousKey: const ValueKey('campaign-page-previous'),
                    nextKey: const ValueKey('campaign-page-next'),
                    onPrevious: campaignPage > 1
                        ? () => loadCampaigns(page: campaignPage - 1)
                        : null,
                    onNext: campaignHasMore
                        ? () => loadCampaigns(page: campaignPage + 1)
                        : null,
                  ),
                ],
              ],
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
                  isExpanded: true,
                  initialValue: selectedShopId,
                  items: [
                    for (final s in shops)
                      DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(
                          s['is_active'] == true
                              ? s['name']
                              : '${s['name']} - fee pending',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => selectedShopId = v),
                  decoration: const InputDecoration(labelText: 'Shop'),
                ),
              if (activeSelectedShop != null &&
                  activeSelectedShop['is_active'] != true) ...[
                const SizedBox(height: 8),
                PaymentInfoBox(
                  icon: Icons.lock_outline,
                  text:
                      '${shopRegistrationStatus(activeSelectedShop)}. Products can be added after ClickPesa confirms the shop registration fee.',
                  active: true,
                ),
              ],
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
              OutlinedButton.icon(
                onPressed: selectedProductVideos.length >= 2
                    ? null
                    : pickProductVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: Text(
                  selectedProductVideos.isEmpty
                      ? 'Add product video (up to 2)'
                      : '${selectedProductVideos.length} of 2 videos chosen',
                ),
              ),
              if (selectedProductVideos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (
                      var index = 0;
                      index < selectedProductVideos.length;
                      index++
                    )
                      InputChip(
                        avatar: const Icon(Icons.videocam_outlined, size: 18),
                        label: Text('Video ${index + 1}'),
                        onDeleted: () => setState(
                          () => selectedProductVideos.removeAt(index),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: selectedShopId == null || !selectedShopCanPublish
                    ? null
                    : () async {
                        try {
                          final targetShopId = selectedShopId!;
                          final images = productImagePaths();
                          if (images.length != 3) {
                            throw Exception(
                              'Choose exactly 3 product images from phone.',
                            );
                          }
                          await widget.client.postMultipartMedia(
                            '/shops/$targetShopId/products',
                            fields: {
                              'name': productName.text,
                              'description': description.text,
                              'price': price.text,
                              'discount_percent': discount.text,
                              'delivery_price': delivery.text,
                              'stock': stock.text,
                            },
                            images: selectedProductImages
                                .map((image) => File(image.path))
                                .toList(),
                            videos: selectedProductVideos
                                .map((video) => File(video.path))
                                .toList(),
                          );
                          setState(() {
                            selectedProductImages = [];
                            selectedProductVideos = [];
                            productPageByShop[targetShopId] = 1;
                          });
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
        if (!loadingShops && shopTotal != null) ...[
          const SizedBox(height: 4),
          Text(
            'Showing ${shops.length} of $shopTotal shops',
            style: const TextStyle(color: kTextColor, fontSize: 12),
          ),
        ],
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
                            const SizedBox(height: 4),
                            Text(
                              shopRegistrationStatus(s as Map<String, dynamic>),
                              style: TextStyle(
                                color: s['is_active'] == true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${s['is_open'] == true ? 'Open now' : 'Closed now'} · ${s['opening_time'] ?? '--:--'}–${s['closing_time'] ?? '--:--'}',
                              style: TextStyle(
                                color: s['is_open'] == true
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('shop-${s['id']}-edit'),
                        tooltip: 'Edit shop',
                        onPressed: deletingShopId == null && !sellerUssdBusy
                            ? () => startEditShop(s)
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: ValueKey('shop-${s['id']}-delete'),
                        tooltip: deletingShopId == s['id']
                            ? 'Deleting shop'
                            : 'Delete shop',
                        onPressed: deletingShopId == null && !sellerUssdBusy
                            ? () => deleteShop(s)
                            : null,
                        color: Colors.red.shade700,
                        icon: deletingShopId == s['id']
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  if (canRetryShopRegistration(s)) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final paymentId = shopRegistrationPaymentId(s);
                        final isResending =
                            paymentId != null &&
                            resendingShopPaymentId == paymentId;
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: ValueKey(
                              'shop-${s['id']}-registration-payment-resend',
                            ),
                            onPressed: sellerUssdBusy
                                ? null
                                : () => resendShopRegistrationPayment(s),
                            icon: isResending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_outlined),
                            label: Text(
                              isResending
                                  ? 'Sending registration payment...'
                                  : 'Resend registration payment',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
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
                            responsiveScheduleButtons(
                              openingKey: ValueKey(
                                'shop-${s['id']}-opening-time',
                              ),
                              closingKey: ValueKey(
                                'shop-${s['id']}-closing-time',
                              ),
                              onOpeningPressed: () =>
                                  pickDraftShopTime(opening: true),
                              onClosingPressed: () =>
                                  pickDraftShopTime(opening: false),
                              openingLabel: 'Opens ${shopDraft!.openingTime}',
                              closingLabel: 'Closes ${shopDraft!.closingTime}',
                            ),
                            const SizedBox(height: 10),
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
                                    key: ValueKey('shop-${s['id']}-save-edit'),
                                    onPressed: () => saveShopEdit(s),
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
                  for (final product in visibleProductsForShop(s))
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
                                OutlinedButton.icon(
                                  onPressed:
                                      clearReplacementProductVideos ||
                                          replacementProductVideos.length >= 2
                                      ? null
                                      : pickReplacementProductVideo,
                                  icon: const Icon(
                                    Icons.video_library_outlined,
                                  ),
                                  label: Text(
                                    replacementProductVideos.isEmpty
                                        ? productVideoCount(product) > 0
                                              ? 'Replace all videos (up to 2)'
                                              : 'Add videos (up to 2)'
                                        : '${replacementProductVideos.length} replacement videos',
                                  ),
                                ),
                                if (replacementProductVideos.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < replacementProductVideos.length;
                                        index++
                                      )
                                        InputChip(
                                          avatar: const Icon(
                                            Icons.videocam_outlined,
                                            size: 18,
                                          ),
                                          label: Text('Video ${index + 1}'),
                                          onDeleted: () => setState(
                                            () => replacementProductVideos
                                                .removeAt(index),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (productVideoCount(product) > 0)
                                  CheckboxListTile(
                                    value: clearReplacementProductVideos,
                                    onChanged: (value) => setState(() {
                                      clearReplacementProductVideos =
                                          value ?? false;
                                      if (clearReplacementProductVideos) {
                                        replacementProductVideos = [];
                                      }
                                    }),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Remove all videos'),
                                    subtitle: const Text(
                                      'Saving will remove every current product video.',
                                    ),
                                  ),
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
                  if (productsForShop(s).length > productPageSize) ...[
                    const SizedBox(height: 2),
                    _SellerPaginationControls(
                      label: productPageLabel(s),
                      previousKey: ValueKey(
                        'shop-${s['id']}-products-previous',
                      ),
                      nextKey: ValueKey('shop-${s['id']}-products-next'),
                      onPrevious: productPageForShop(s) > 1
                          ? () =>
                                changeProductPage(s, productPageForShop(s) - 1)
                          : null,
                      onNext: productPageForShop(s) < productPageCount(s)
                          ? () =>
                                changeProductPage(s, productPageForShop(s) + 1)
                          : null,
                    ),
                  ],
                  if (productsForShop(s).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        s['is_active'] == true
                            ? 'No products in this shop yet.'
                            : 'Pay the registration fee to activate this shop and start adding products.',
                        style: const TextStyle(color: kTextColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (!loadingShops && shopHasMore) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loadingMoreShops ? null : () => load(append: true),
            icon: loadingMoreShops
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(loadingMoreShops ? 'Loading...' : 'Load more shops'),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }
}

class _SellerPaginationControls extends StatelessWidget {
  const _SellerPaginationControls({
    required this.label,
    required this.previousKey,
    required this.nextKey,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final Key previousKey;
  final Key nextKey;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: previousKey,
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: nextKey,
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShopEditDraft {
  _ShopEditDraft({
    required String name,
    required String address,
    required Set<String> categories,
    required this.openingTime,
    required this.closingTime,
  }) : name = TextEditingController(text: name),
       address = TextEditingController(text: address),
       categories = {...categories};

  final TextEditingController name;
  final TextEditingController address;
  final Set<String> categories;
  String openingTime;
  String closingTime;

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
  const DeliveryPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List jobs = [];
  final code = TextEditingController();
  Timer? locationTimer;
  bool sharingLocation = false;
  bool loading = true;
  bool refreshing = false;
  bool loadingMoreJobs = false;
  bool updatingAvailability = false;
  bool isAvailable = true;
  int jobPage = 1;
  int? jobTotal;
  bool jobHasMore = false;
  int? acceptingJobId;
  int? completingJobId;
  DateTime? lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    isAvailable = widget.user['is_available'] != false;
    load(showLoading: true);
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

  Future<void> load({
    bool showLoading = false,
    bool silent = false,
    bool append = false,
  }) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    } else if (append && mounted) {
      setState(() => loadingMoreJobs = true);
    } else if (!silent && mounted) {
      setState(() => refreshing = true);
    }
    final page = append ? jobPage + 1 : 1;
    try {
      final r = await widget.client.get('/deliveries', {
        'page': '$page',
        'per_page': '20',
      });
      final jobResponse = r['jobs'];
      final nextJobs = responseItems(jobResponse);
      if (mounted) {
        setState(() {
          jobs = append ? [...jobs, ...nextJobs] : nextJobs;
          jobPage = page;
          jobTotal = responseTotal(jobResponse);
          jobHasMore = responseHasMore(jobResponse);
          isAvailable = r['is_available'] != false;
          lastRefreshedAt = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted && !silent) showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
          loadingMoreJobs = false;
        });
      }
    }
  }

  Future<void> setAvailability(bool value) async {
    setState(() {
      updatingAvailability = true;
      isAvailable = value;
    });
    try {
      final r = await widget.client.post('/deliverer/availability', {
        'is_available': value,
      });
      if (r['user'] is Map<String, dynamic>) {
        widget.onUserChanged(r['user'] as Map<String, dynamic>);
      }
      if (!mounted) return;
      setState(() => isAvailable = r['is_available'] != false);
      await load(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Availability updated.'}')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => isAvailable = !value);
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => updatingAvailability = false);
    }
  }

  Future<void> acceptDelivery(Map<String, dynamic> job) async {
    final id = job['id'] as int?;
    if (id == null) return;
    setState(() => acceptingJobId = id);
    try {
      await widget.client.post('/deliveries/$id/accept', {});
      await load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => acceptingJobId = null);
    }
  }

  Future<void> completeDelivery(Map<String, dynamic> job) async {
    final id = job['id'] as int?;
    if (id == null) return;
    final deliveryCode = code.text.trim();
    if (deliveryCode.length != 4 ||
        deliveryCode.split('').toSet().length != 4) {
      showError(context, 'Enter exactly 4 different digits from the buyer.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete delivery?'),
        content: Text(
          'Confirm buyer code $deliveryCode for order ${job['order']?['reference'] ?? ''}. This will mark the delivery complete and trigger seller and delivery payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => completingJobId = id);
    try {
      final r = await widget.client.post('/deliveries/$id/complete', {
        'delivery_code': deliveryCode,
      });
      code.clear();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Delivery completed.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => completingJobId = null);
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
      await load(silent: true);
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
      onRefresh: () => load(silent: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isAvailable,
                  onChanged: updatingAvailability ? null : setAvailability,
                  title: const Text('Available for deliveries'),
                  subtitle: Text(
                    isAvailable
                        ? 'New nearby delivery requests can be assigned to you.'
                        : 'You will not receive new delivery requests.',
                  ),
                ),
                if (updatingAvailability || refreshing || sharingLocation)
                  const LinearProgressIndicator(minHeight: 3),
                if (lastRefreshedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${DateFormat('HH:mm:ss').format(lastRefreshedAt!)}',
                    style: const TextStyle(color: kTextColor, fontSize: 12),
                  ),
                ],
                if (!loading && jobTotal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Showing ${jobs.length} of $jobTotal jobs',
                    style: const TextStyle(color: kTextColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                          onPressed: acceptingJobId == j['id']
                              ? null
                              : () => acceptDelivery(j),
                          icon: acceptingJobId == j['id']
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            acceptingJobId == j['id']
                                ? 'Accepting...'
                                : 'Accept delivery',
                          ),
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
                          onPressed: completingJobId == j['id']
                              ? null
                              : () => completeDelivery(j),
                          icon: completingJobId == j['id']
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.payments),
                          label: Text(
                            completingJobId == j['id']
                                ? 'Completing delivery...'
                                : 'Confirm code and release payments',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (!loading && jobHasMore)
            OutlinedButton.icon(
              onPressed: loadingMoreJobs ? null : () => load(append: true),
              icon: loadingMoreJobs
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(loadingMoreJobs ? 'Loading...' : 'Load more jobs'),
            ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUnreadCountChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<int> onUnreadCountChanged;
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
          conversations = responseItems(r['conversations']);
          loading = false;
        });
        widget.onUnreadCountChanged(
          unreadCountFromConversations(conversations),
        );
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
    final unreadCount =
        int.tryParse('${conversation['unread_count'] ?? 0}') ?? 0;
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
      trailing: unreadCount > 0
          ? Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chevron_right),
            )
          : const Icon(Icons.chevron_right),
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
    final r = await widget.client.get('/chat/contacts', {
      'page': '1',
      'per_page': '50',
    });
    if (!mounted) return;
    setState(() {
      contacts = responseItems(r['contacts']);
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
      final loadedConversation = r['conversation'];
      if (loadedConversation is Map) {
        conversation = Map<String, dynamic>.from(loadedConversation);
      }
      messages = responseItems(r['messages']);
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

class PaymentSummaryRow extends StatelessWidget {
  const PaymentSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
      color: strong ? Colors.black : kTextColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class PaymentInfoBox extends StatelessWidget {
  const PaymentInfoBox({
    super.key,
    required this.icon,
    required this.text,
    this.active = false,
  });

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? kPrimaryLightColor : kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? kPrimaryColor.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? kPrimaryColor : kTextColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: active ? kPrimaryColor : kTextColor,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
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

List<Map<String, dynamic>> productMediaSources(
  Map<String, dynamic> product, {
  required String fallback,
}) {
  final media = product['media'];
  if (media is List) {
    final sources =
        media
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => '${item['url'] ?? ''}'.trim().isNotEmpty)
            .toList()
          ..sort(
            (a, b) => (int.tryParse('${a['position'] ?? 0}') ?? 0).compareTo(
              int.tryParse('${b['position'] ?? 0}') ?? 0,
            ),
          );
    if (sources.isNotEmpty) return sources;
  }
  return [
    for (final source in productImageSources(product, fallback: fallback))
      {'type': 'image', 'url': source},
  ];
}

int productVideoCount(Map<String, dynamic> product) => productMediaSources(
  product,
  fallback: '',
).where((item) => item['type'] == 'video').length;

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

class ProductMediaTile extends StatefulWidget {
  const ProductMediaTile({
    super.key,
    required this.media,
    required this.active,
    this.fit = BoxFit.contain,
  });

  final Map<String, dynamic> media;
  final bool active;
  final BoxFit fit;

  @override
  State<ProductMediaTile> createState() => _ProductMediaTileState();
}

class _ProductMediaTileState extends State<ProductMediaTile> {
  VideoPlayerController? controller;
  Future<void>? initialization;

  bool get isVideo => widget.media['type'] == 'video';
  String get source => '${widget.media['url'] ?? ''}';

  @override
  void initState() {
    super.initState();
    initializeVideo();
  }

  @override
  void didUpdateWidget(covariant ProductMediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media['url'] != widget.media['url'] ||
        oldWidget.media['type'] != widget.media['type']) {
      disposeVideo();
      initializeVideo();
      return;
    }
    if (!oldWidget.active && widget.active) {
      unawaited(playVideo());
    }
    if (oldWidget.active && !widget.active) {
      pauseVideo();
    }
  }

  void initializeVideo() {
    if (!isVideo || source.isEmpty) return;
    final uri = Uri.tryParse(source);
    final nextController =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? VideoPlayerController.networkUrl(uri)
        : VideoPlayerController.file(File(source));
    controller = nextController;
    initialization = nextController.initialize().then((_) async {
      if (!mounted || controller != nextController) return;
      await nextController.setLooping(true);
      if (!mounted || controller != nextController) return;
      if (widget.active) {
        await nextController.play();
      } else {
        await nextController.pause();
      }
      if (mounted && controller == nextController) setState(() {});
    });
  }

  Future<void> playVideo() async {
    final player = controller;
    if (player == null ||
        !player.value.isInitialized ||
        player.value.isPlaying ||
        !widget.active) {
      return;
    }
    await player.play();
    if (mounted && controller == player) setState(() {});
  }

  void pauseVideo() {
    final player = controller;
    if (player == null ||
        !player.value.isInitialized ||
        !player.value.isPlaying) {
      return;
    }
    unawaited(
      player.pause().whenComplete(() {
        if (mounted && controller == player) setState(() {});
      }),
    );
  }

  void disposeVideo() {
    final player = controller;
    controller = null;
    initialization = null;
    if (player != null) unawaited(player.dispose());
  }

  Future<void> toggleVideo() async {
    final player = controller;
    if (player == null || !player.value.isInitialized || !widget.active) {
      return;
    }
    if (player.value.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted && controller == player && !widget.active) {
      await player.pause();
    }
    if (mounted && controller == player) setState(() {});
  }

  @override
  void dispose() {
    disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return ProductImage(source: source, fit: widget.fit);
    }
    final player = controller;
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.broken_image_outlined));
        }
        if (snapshot.connectionState != ConnectionState.done ||
            player == null ||
            !player.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.active ? toggleVideo : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio == 0
                      ? 1
                      : player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: player.value.isPlaying ? 0.24 : 1,
                  child: IconButton.filled(
                    tooltip: player.value.isPlaying
                        ? 'Pause video'
                        : 'Play video',
                    onPressed: widget.active ? toggleVideo : null,
                    icon: Icon(
                      player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProductMediaCarousel extends StatefulWidget {
  const ProductMediaCarousel({super.key, required this.media});

  final List<Map<String, dynamic>> media;

  @override
  State<ProductMediaCarousel> createState() => _ProductMediaCarouselState();
}

class _ProductMediaCarouselState extends State<ProductMediaCarousel> {
  int current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: PageView.builder(
            itemCount: widget.media.length,
            onPageChanged: (index) => setState(() => current = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: kSurfaceColor),
                  child: ProductMediaTile(
                    media: widget.media[index],
                    active: index == current,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.media.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.media.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: current == index ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: current == index ? kPrimaryColor : Colors.black26,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
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
    required this.onShare,
    required this.onRate,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;
  final Future<void> Function() onShare;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final original = num.tryParse('${product['price']}') ?? 0;
    final discounted = num.tryParse('${product['discount_price'] ?? ''}');
    final itemPrice = discounted ?? original;
    final discount = num.tryParse('${product['discount_percent']}') ?? 0;
    final matchPercent = productImageMatchPercent(product);
    final videoCount = productVideoCount(product);
    final shopOpen = product['shop']?['is_open'] == true;
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
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
            onShare: onShare,
            onRate: onRate,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: kSurfaceColor),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: ProductImage(
                              source: imageAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (matchPercent != null)
                            Align(
                              alignment: Alignment.topLeft,
                              child: _ProductBadge(
                                label: '$matchPercent% match',
                                color: Colors.black87,
                              ),
                            ),
                          if (discount > 0)
                            Align(
                              alignment: Alignment.topRight,
                              child: _ProductBadge(
                                label: '${discount.toStringAsFixed(0)}% off',
                                color: kPrimaryColor,
                              ),
                            ),
                          if (videoCount > 0)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: _ProductBadge(
                                label:
                                    '$videoCount video${videoCount == 1 ? '' : 's'}',
                                color: Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product['name'] ?? 'Product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product['shop']?['name'] ?? ''} · ${shopOpen ? 'Open' : 'Closed'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shopOpen
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RatingSummary(product: product, compact: true),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TZS ${money.format(itemPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _ProductIconAction(
                      tooltip: tx('Add to cart', 'Weka kikapuni'),
                      onPressed: onAdd,
                      icon: Icons.add_shopping_cart,
                      filled: true,
                    ),
                  ],
                ),
                if (original > itemPrice)
                  Text(
                    'TZS ${money.format(original)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(7),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProductIconAction extends StatelessWidget {
  const _ProductIconAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.filled = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: filled ? kPrimaryColor : Colors.white,
        foregroundColor: filled ? Colors.white : Colors.black87,
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        shape: const CircleBorder(),
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
    required this.onShare,
    required this.onRate,
  });
  final Map<String, dynamic> product;
  final NumberFormat money;
  final String imageAsset;
  final Future<void> Function() onAdd;
  final Future<void> Function() onStartChat;
  final Future<void> Function() onShare;
  final Future<void> Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final total = num.tryParse('${product['auto_total']}') ?? 0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final media = productMediaSources(product, fallback: imageAsset);
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
              ProductMediaCarousel(media: media),
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
              if (product['shop'] is Map) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final shop = product['shop'] as Map;
                    final open = shop['is_open'] == true;
                    return StatusPill(
                      label:
                          '${open ? 'Open now' : 'Closed now'} · ${shop['opening_time'] ?? '--:--'}–${shop['closing_time'] ?? '--:--'}',
                      color: open ? Colors.green.shade700 : Colors.red.shade700,
                    );
                  },
                ),
              ],
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
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share download link'),
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
