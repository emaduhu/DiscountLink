part of '../../../main.dart';

class NotificationInboxService {
  const NotificationInboxService();

  static const _storage = FlutterSecureStorage();
  static const _itemsKey = 'discountlink.notifications.items';
  static const _maxItems = 100;

  Future<List<StoredNotification>> all() async {
    final raw = await _storage.read(key: _itemsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                StoredNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> count() async => (await all()).length;

  Future<int> add(StoredNotification notification) async {
    final items = await all();
    final next = [
      notification,
      ...items.where((item) => item.id != notification.id),
    ].take(_maxItems).toList();
    await _save(next);
    return next.length;
  }

  Future<int> delete(String id) async {
    final items = await all();
    final next = items.where((item) => item.id != id).toList();
    await _save(next);
    return next.length;
  }

  Future<int> clear() async {
    await _save([]);
    return 0;
  }

  Future<void> _save(List<StoredNotification> items) async {
    await _storage.write(
      key: _itemsKey,
      value: jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
