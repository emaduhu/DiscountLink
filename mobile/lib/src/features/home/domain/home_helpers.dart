part of '../../../../main.dart';

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
