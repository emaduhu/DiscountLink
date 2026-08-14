part of '../../../../../main.dart';

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final dynamic currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversationOther(conversation, currentUserId);
    final name =
        other?['name'] ??
        '${tx('Conversation', 'Mazungumzo')} #${conversation['id']}';
    final role = other?['role'] ?? '';
    final messages = (conversation['messages'] as List?) ?? [];
    final last = messages.isEmpty
        ? null
        : messages.last as Map<String, dynamic>;
    final unreadCount =
        int.tryParse('${conversation['unread_count'] ?? 0}') ?? 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: kPrimaryLightColor,
        child: Text(
          initials(name),
          style: const TextStyle(
            color: kPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        last?['body'] ?? role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unreadCount > 0
          ? Badge(
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.chevron_right),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
