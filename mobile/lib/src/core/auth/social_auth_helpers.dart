part of '../../../main.dart';

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
      '_email': googleUser.email,
      '_phone': null,
    };
  } on GoogleSignInException catch (error) {
    throw Exception(googleSignInErrorMessage(error));
  }
}

Future<AppleSignInResult> signInWithAppleFirebase() async {
  await ensureFirebaseInitialized(feature: 'Apple sign-in');

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return signInWithAppleNativeFirebase();
  }

  try {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final firebaseCredential =
        await (kIsWeb
                ? FirebaseAuth.instance.signInWithPopup(provider)
                : FirebaseAuth.instance.signInWithProvider(provider))
            .timeout(const Duration(minutes: 2));
    final firebaseUser = firebaseCredential.user;
    if (firebaseUser == null) {
      throw Exception(
        'Apple sign-in finished, but Firebase did not return a user. Try again.',
      );
    }
    return AppleSignInResult(
      credential: firebaseCredential,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
    );
  } on UnimplementedError {
    return signInWithAppleNativeFirebase();
  } on TimeoutException {
    return signInWithAppleNativeFirebase();
  } on FirebaseAuthException catch (error) {
    if (error.code == 'web-context-cancelled' ||
        error.code == 'user-cancelled' ||
        error.code == 'canceled' ||
        error.code == 'operation-not-allowed') {
      throw Exception(appleSignInErrorMessage(error));
    }
    return signInWithAppleNativeFirebase();
  }
}

Future<AppleSignInResult> signInWithAppleNativeFirebase() async {
  try {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw Exception(
        'Apple sign-in is not available on this device. Use an iPhone or iPad signed in to iCloud.',
      );
    }

    final rawNonce = generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    ).timeout(const Duration(minutes: 2));

    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw Exception(
        'Apple sign-in did not return an identity token. Try again and make sure Apple sign-in is enabled for this app identifier.',
      );
    }

    final oauthCredential = AppleAuthProvider.credentialWithIDToken(
      identityToken,
      rawNonce,
      AppleFullPersonName(
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
      ),
    );
    final firebaseCredential = await FirebaseAuth.instance
        .signInWithCredential(oauthCredential)
        .timeout(const Duration(minutes: 2));

    return AppleSignInResult(
      credential: firebaseCredential,
      email: appleCredential.email ?? firebaseCredential.user?.email,
      displayName:
          appleCredentialDisplayName(appleCredential) ??
          firebaseCredential.user?.displayName,
    );
  } on TimeoutException {
    throw Exception(
      'Apple sign-in did not finish. Close the Apple sign-in sheet and try again. If you are using the simulator, test on a physical iPhone signed in to iCloud.',
    );
  } on SignInWithAppleAuthorizationException catch (error) {
    throw Exception(nativeAppleSignInErrorMessage(error));
  } on SignInWithAppleNotSupportedException catch (error) {
    throw Exception(error.message);
  } on SignInWithAppleException catch (error) {
    throw Exception('Apple sign-in failed: $error');
  } on FirebaseAuthException catch (error) {
    throw Exception(appleSignInErrorMessage(error));
  }
}

Future<String> refreshedFirebaseIdToken(
  User? user, {
  required String feature,
}) async {
  if (user == null) {
    throw Exception('$feature did not return a Firebase user.');
  }
  try {
    await user.reload().timeout(const Duration(seconds: 20));
  } catch (_) {}
  final currentUser = FirebaseAuth.instance.currentUser ?? user;
  final token = await currentUser
      .getIdToken(true)
      .timeout(const Duration(seconds: 30));
  if (token == null || token.isEmpty) {
    throw Exception('Firebase did not return an ID token.');
  }
  return token;
}

String? appleCredentialDisplayName(AuthorizationCredentialAppleID credential) {
  final parts = [credential.givenName, credential.familyName]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  return parts.join(' ');
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

String nativeAppleSignInErrorMessage(
  SignInWithAppleAuthorizationException error,
) {
  if (error.code == AuthorizationErrorCode.canceled) {
    return 'Apple sign-in was cancelled.';
  }
  if (error.code == AuthorizationErrorCode.notHandled) {
    return 'Apple sign-in was not handled. Check that Sign in with Apple is enabled for the iOS app identifier.';
  }
  if (error.code == AuthorizationErrorCode.invalidResponse) {
    return 'Apple sign-in returned an invalid response. Try again, and if it persists remove this app from your Apple ID Sign in with Apple settings before retrying.';
  }
  return error.message.isNotEmpty
      ? error.message
      : 'Apple sign-in failed. Please try again.';
}

String appleSignInErrorMessage(FirebaseAuthException error) {
  if (error.code == 'web-context-cancelled' ||
      error.code == 'user-cancelled' ||
      error.code == 'canceled') {
    return 'Apple sign-in was cancelled.';
  }
  if (error.code == 'operation-not-allowed') {
    return 'Apple sign-in is not enabled in Firebase Authentication.';
  }
  if (error.code == 'invalid-credential') {
    return 'Apple sign-in returned an invalid credential. Try again and make sure you share your email address.';
  }
  return error.message ?? 'Apple sign-in failed. Please try again.';
}
