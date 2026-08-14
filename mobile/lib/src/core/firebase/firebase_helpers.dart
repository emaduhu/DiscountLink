part of '../../../main.dart';

Future<void> initializeFirebase() async {
  try {
    await ensureFirebaseInitialized();
  } catch (_) {}
}

Future<void> ensureFirebaseInitialized({String feature = 'Firebase'}) async {
  if (Firebase.apps.isNotEmpty) return;

  Object? primaryError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  } catch (error) {
    primaryError = error;
  }

  if (Firebase.apps.isNotEmpty) return;

  try {
    await Firebase.initializeApp();
  } catch (fallbackError) {
    if (Firebase.apps.isNotEmpty) return;
    throw Exception(
      firebaseConfigurationMessage(
        feature: feature,
        primaryError: primaryError,
        fallbackError: fallbackError,
      ),
    );
  }
}

String firebaseConfigurationMessage({
  required String feature,
  required Object? primaryError,
  required Object fallbackError,
}) {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    final plistPath = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios/Runner/GoogleService-Info.plist'
        : 'macos/Runner/GoogleService-Info.plist';
    return '$feature requires Firebase to be configured for $platform. Add the $platform app in Firebase, place GoogleService-Info.plist at $plistPath, then run FlutterFire configure so lib/firebase_options.dart includes $platform.';
  }

  return '$feature requires Firebase, but Firebase could not be initialized: ${primaryError ?? fallbackError}';
}

bool get usesApplePushToken =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Future<String?> firebaseMessagingToken() async {
  try {
    if (!await notificationPreferences.isEnabled()) return null;
    await ensureFirebaseInitialized(feature: 'push notifications');
    if (usesApplePushToken) {
      final apnsToken = await waitForApnsToken();
      if (apnsToken == null) return null;
    }
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
}

Future<String?> waitForApnsToken() async {
  for (var attempt = 0; attempt < 10; attempt += 1) {
    final token = await FirebaseMessaging.instance.getAPNSToken();
    if (token != null && token.isNotEmpty) return token;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return null;
}
