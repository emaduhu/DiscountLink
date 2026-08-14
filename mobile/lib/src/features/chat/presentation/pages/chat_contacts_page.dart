part of '../../../../../main.dart';

class ChatContactsPage extends StatefulWidget {
  const ChatContactsPage({super.key, required this.client});
  final ApiClient client;

  @override
  State<ChatContactsPage> createState() => _ChatContactsPageState();
}
