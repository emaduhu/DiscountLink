part of '../../../../main.dart';

int profileIndexForRole(String role) => switch (role) {
  'buyer' => 3,
  'seller' => 4,
  'deliverer' => 2,
  _ => 1,
};

int homePageCountForRole(String role) => switch (role) {
  'buyer' => 4,
  'seller' => 5,
  'deliverer' => 3,
  _ => 2,
};

int normalizedHomeIndexForRole(String role, int index) {
  final lastIndex = homePageCountForRole(role) - 1;
  if (index < 0) return 0;
  if (index > lastIndex) return lastIndex;
  return index;
}

int unreadCountFromConversations(List conversations) {
  var total = 0;
  for (final item in conversations) {
    if (item is! Map) continue;
    total += int.tryParse('${item['unread_count'] ?? 0}') ?? 0;
  }

  return total;
}
