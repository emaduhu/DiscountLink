part of '../../../../../main.dart';

class _ChatPageState extends State<ChatPage> {
  List conversations = [];
  Timer? refreshTimer;
  bool refreshing = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final r = await widget.client.get('/conversations');
      if (mounted) {
        setState(() {
          conversations = responseItems(r['conversations']);
          loading = false;
        });
        widget.onUnreadCountChanged(
          unreadCountFromConversations(conversations),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => loading = false);
        showError(context, error);
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> showStartChatPage() async {
    final conversation = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChatContactsPage(client: widget.client),
      ),
    );
    if (conversation == null || !mounted) return;
    await load();
    if (!mounted) return;
    await openConversation(conversation);
  }

  Future<void> openConversation(Map<String, dynamic> conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatConversationPage(
          client: widget.client,
          user: widget.user,
          conversation: conversation,
        ),
      ),
    );
    if (!mounted) return;
    await load();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator(
        onRefresh: load,
        child: ResponsiveListView(
          maxWidth: kResponsiveContentMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SectionTitle(title: tx('Chats', 'Mazungumzo')),
            const SizedBox(height: 8),
            if (loading)
              const ListLoadingIndicator()
            else if (conversations.isEmpty)
              EmptyState(
                icon: Icons.chat_bubble_outline,
                title: tx('No conversations yet', 'Bado hakuna mazungumzo'),
                subtitle: tx(
                  'Start a chat with a seller, buyer, or deliverer.',
                  'Anzisha mazungumzo na muuzaji, mnunuzi, au msafirishaji.',
                ),
              ),
            for (final item in conversations)
              ChatListTile(
                conversation: item as Map<String, dynamic>,
                currentUserId: widget.user['id'],
                onTap: () => openConversation(item),
              ),
          ],
        ),
      ),
      Positioned(
        right: 18,
        bottom: 18,
        child: FloatingActionButton.extended(
          onPressed: showStartChatPage,
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(tx('New chat', 'Soga jipya')),
        ),
      ),
    ],
  );
}
