part of '../../../../../main.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.client,
    required this.user,
    required this.conversation,
  });

  final ApiClient client;
  final Map<String, dynamic> user;
  final Map<String, dynamic> conversation;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}
