part of '../../../main.dart';

class NotificationPreferenceService {
  const NotificationPreferenceService();

  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'discountlink.notifications.enabled';

  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value != 'false';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }
}
