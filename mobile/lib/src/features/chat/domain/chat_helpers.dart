part of '../../../../main.dart';

String? discountOfferToken(String body) {
  final match = RegExp(r'discountlink://offer/([A-Za-z0-9]+)').firstMatch(body);
  return match?.group(1);
}

String chatMessageTime(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('HH:mm').format(parsed.toLocal());
}

String chatDeliveryStatus(Map<String, dynamic> message, bool mine) {
  if (!mine) return '';
  final readAt = '${message['read_at'] ?? ''}'.trim();
  return readAt.isEmpty
      ? tx('Delivered', 'Imefikishwa')
      : tx('Read', 'Imesomwa');
}

Map<String, dynamic>? conversationOther(
  Map<String, dynamic> conversation,
  dynamic currentUserId,
) {
  final one = conversation['user_one'] as Map<String, dynamic>?;
  final two = conversation['user_two'] as Map<String, dynamic>?;
  return conversation['user_one_id'] == currentUserId ? two : one;
}
