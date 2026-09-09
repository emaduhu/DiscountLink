part of '../../../main.dart';

class PersistedSession {
  const PersistedSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

class SessionPersistenceService {
  const SessionPersistenceService();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'discountlink.session.token';
  static const _userKey = 'discountlink.session.user';
  static const _splashSeenKey = 'discountlink.session.splash_seen';
  static const _homeIndexKey = 'discountlink.session.home_index';

  Future<PersistedSession?> restore() async {
    final token = (await _storage.read(key: _tokenKey))?.trim();
    final rawUser = await _storage.read(key: _userKey);
    if (token == null || token.isEmpty || rawUser == null) return null;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map) return null;

      return PersistedSession(
        token: token,
        user: Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
    await setSplashSeen();
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _homeIndexKey);
  }

  Future<bool> hasSeenSplash() async {
    return await _storage.read(key: _splashSeenKey) == 'true';
  }

  Future<void> setSplashSeen() async {
    await _storage.write(key: _splashSeenKey, value: 'true');
  }

  Future<int?> homeIndex() async {
    final value = await _storage.read(key: _homeIndexKey);
    return int.tryParse(value ?? '');
  }

  Future<void> setHomeIndex(int index) async {
    await _storage.write(key: _homeIndexKey, value: '$index');
  }
}
