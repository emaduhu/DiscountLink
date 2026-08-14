part of '../../../main.dart';

class BiometricAuthService {
  const BiometricAuthService();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'discountlink.biometric.token';
  static const _emailKey = 'discountlink.biometric.email';
  static const _nameKey = 'discountlink.biometric.name';

  Future<bool> canUseBiometrics() async {
    return (await availableBiometrics()).isNotEmpty;
  }

  Future<List<BiometricType>> availableBiometrics() async {
    if (kIsWeb) return const [];
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics) {
        return const [];
      }
      return await auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  Future<String> methodLabel() async {
    final biometrics = await availableBiometrics();
    if (biometrics.contains(BiometricType.face)) return 'Face ID';
    if (biometrics.contains(BiometricType.fingerprint)) {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        return 'Touch ID';
      }
      return 'fingerprint';
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return 'Face ID or Touch ID';
    }
    return 'biometrics';
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
    final available = await canUseBiometrics();
    if (!available) {
      throw Exception(
        'Biometric unlock is not available on this device. Set up Face ID, Touch ID, or fingerprint unlock first.',
      );
    }

    final auth = LocalAuthentication();
    return auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<String?> unlockToken() async {
    final method = await methodLabel();
    final ok = await authenticate('Use $method to unlock Discount Link');
    if (!ok) return null;

    return _storage.read(key: _tokenKey);
  }
}
