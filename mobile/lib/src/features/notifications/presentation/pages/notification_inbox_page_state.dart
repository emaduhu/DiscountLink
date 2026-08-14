part of '../../../../../main.dart';

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  List<StoredNotification> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final items = await notificationInbox.all();
    if (!mounted) return;
    setState(() {
      notifications = items;
      loading = false;
    });
  }

  Future<void> copyNotification(StoredNotification notification) async {
    await Clipboard.setData(ClipboardData(text: notification.copyText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('Notification copied.', 'Arifa imenakiliwa.'))),
    );
  }

  Future<void> deleteNotification(StoredNotification notification) async {
    await notificationInbox.delete(notification.id);
    if (!mounted) return;
    setState(
      () => notifications = notifications
          .where((item) => item.id != notification.id)
          .toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('Notification deleted.', 'Arifa imefutwa.'))),
    );
  }

  Future<void> clearNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx('Delete all notifications?', 'Futa arifa zote?')),
        content: Text(
          tx(
            'This removes the notification list stored on this device.',
            'Hii itaondoa orodha ya arifa zilizohifadhiwa kwenye kifaa hiki.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tx('Cancel', 'Ghairi')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tx('Delete all', 'Futa zote')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await notificationInbox.clear();
    if (!mounted) return;
    setState(() => notifications = []);
  }

  @override
  Widget build(BuildContext context) {
    final count = notifications.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Notifications', 'Arifa')),
        actions: [
          if (count > 0)
            IconButton(
              tooltip: tx('Delete all', 'Futa zote'),
              onPressed: clearNotifications,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: loading
          ? const ListLoadingIndicator()
          : RefreshIndicator(
              onRefresh: load,
              child: notifications.isEmpty
                  ? ResponsiveListView(
                      maxWidth: kResponsiveContentMaxWidth,
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 64),
                        EmptyState(
                          icon: Icons.notifications_none_outlined,
                          title: tx(
                            'No notifications yet',
                            'Bado hakuna arifa',
                          ),
                          subtitle: tx(
                            'Order, chat, and delivery alerts will appear here.',
                            'Arifa za oda, soga, na usafirishaji zitaonekana hapa.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return ResponsiveCenter(
                          maxWidth: kResponsiveContentMaxWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SurfacePanel(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  14,
                                  8,
                                  8,
                                  8,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: kPrimaryLightColor,
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    color: kPrimaryColor,
                                  ),
                                ),
                                title: Text(
                                  notification.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (notification.body.isNotEmpty)
                                        Text(
                                          notification.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatDateTime(
                                          notification.receivedAt
                                              .toIso8601String(),
                                        ),
                                        style: const TextStyle(
                                          color: kTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: SizedBox(
                                  width: 96,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        tooltip: tx('Copy', 'Nakili'),
                                        onPressed: () =>
                                            copyNotification(notification),
                                        icon: const Icon(Icons.copy_rounded),
                                      ),
                                      IconButton(
                                        tooltip: tx('Delete', 'Futa'),
                                        onPressed: () =>
                                            deleteNotification(notification),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
