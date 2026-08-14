part of '../../../main.dart';

class StoredNotification {
  const StoredNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.data,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final Map<String, String> data;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'received_at': receivedAt.toIso8601String(),
    'data': data,
  };

  factory StoredNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final parsedData = rawData is Map
        ? rawData.map((key, value) => MapEntry('$key', '$value'))
        : <String, String>{};
    return StoredNotification(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? kAppName}'.trim(),
      body: '${json['body'] ?? ''}'.trim(),
      receivedAt:
          DateTime.tryParse('${json['received_at'] ?? ''}') ?? DateTime.now(),
      data: parsedData,
    );
  }

  String get copyText {
    final parts = [
      title.trim().isEmpty ? kAppName : title.trim(),
      if (body.trim().isNotEmpty) body.trim(),
      formatDateTime(receivedAt.toIso8601String()),
      if (data.isNotEmpty)
        data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n'),
    ];
    return parts.join('\n\n');
  }
}
