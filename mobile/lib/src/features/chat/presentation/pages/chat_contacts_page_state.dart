part of '../../../../../main.dart';

class _ChatContactsPageState extends State<ChatContactsPage> {
  List contacts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await widget.client.get('/chat/contacts', {
      'page': '1',
      'per_page': '50',
    });
    if (!mounted) return;
    setState(() {
      contacts = responseItems(r['contacts']);
      loading = false;
    });
  }

  Future<void> startChat(Map<String, dynamic> contact) async {
    final r = await widget.client.post('/conversations', {
      'user_id': contact['id'],
    });
    if (!mounted) return;
    Navigator.pop(context, r['conversation'] as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx('New chat', 'Soga jipya'))),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ResponsiveListView(
              maxWidth: kResponsiveContentMaxWidth,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                if (contacts.isEmpty)
                  EmptyState(
                    icon: Icons.people_outline,
                    title: tx('No contacts', 'Hakuna anwani'),
                    subtitle: tx(
                      'Users available for chat will appear here.',
                      'Watumiaji wa kuzungumza nao wataonekana hapa.',
                    ),
                  ),
                for (final item in contacts)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: kPrimaryLightColor,
                      child: Text(
                        initials(item['name'] ?? 'DL'),
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${item['role']} - ${item['phone'] ?? ''}'),
                    onTap: () => startChat(item as Map<String, dynamic>),
                  ),
              ],
            ),
          ),
  );
}
