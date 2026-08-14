part of '../../../main.dart';

StoredNotification storedNotificationFromRemoteMessage(
  RemoteMessage message, {
  required String title,
  required String body,
}) {
  final data = message.data.map((key, value) => MapEntry(key, '$value'));
  final sentAt = message.sentTime ?? DateTime.now();
  final explicitId = [message.messageId, data['notification_id'], data['id']]
      .whereType<String>()
      .map((value) => value.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final id = explicitId.isNotEmpty
      ? explicitId
      : sha1
            .convert(
              utf8.encode(
                [
                  title,
                  body,
                  sentAt.toIso8601String(),
                  jsonEncode(data),
                ].join('|'),
              ),
            )
            .toString();

  return StoredNotification(
    id: id,
    title: title.trim().isEmpty ? kAppName : title.trim(),
    body: body.trim(),
    receivedAt: sentAt,
    data: data,
  );
}
