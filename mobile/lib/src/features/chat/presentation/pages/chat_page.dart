part of '../../../../../main.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUnreadCountChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<int> onUnreadCountChanged;
  @override
  State<ChatPage> createState() => _ChatPageState();
}
