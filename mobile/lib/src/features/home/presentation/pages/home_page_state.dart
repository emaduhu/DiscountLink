part of '../../../../../main.dart';

class _HomePageState extends State<HomePage> {
  int index = 0;
  int unreadChatCount = 0;
  Timer? unreadChatTimer;

  @override
  void initState() {
    super.initState();
    final role = widget.user['role'] as String;
    index = normalizedHomeIndexForRole(role, widget.initialIndex);
    if (widget.user['_open_phone_verification'] == true ||
        widget.user['email_verified_at'] == null ||
        widget.user['phone_verified_at'] == null) {
      index = profileIndexForRole(role);
    }
    widget.onSelectedIndexChanged(index);
    loadUnreadChatCount();
    unreadChatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadUnreadChatCount(),
    );
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final role = widget.user['role'] as String;
    final nextIndex = normalizedHomeIndexForRole(role, index);
    if (nextIndex == index) return;
    setState(() => index = nextIndex);
    widget.onSelectedIndexChanged(nextIndex);
  }

  @override
  void dispose() {
    unreadChatTimer?.cancel();
    super.dispose();
  }

  Future<void> loadUnreadChatCount() async {
    try {
      final r = await widget.client.get('/conversations');
      final conversations = responseItems(r['conversations']);
      updateUnreadChatCount(unreadCountFromConversations(conversations));
    } catch (_) {}
  }

  void updateUnreadChatCount(int count) {
    if (!mounted || count == unreadChatCount) return;
    setState(() => unreadChatCount = count);
  }

  Widget chatDestinationIcon(IconData icon) {
    final count = unreadChatCount;
    if (count <= 0) return Icon(icon);

    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: Icon(icon));
  }

  Future<void> openNotificationInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NotificationInboxPage()),
    );
    if (!mounted) return;
    await widget.onNotificationInboxChanged();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] as String;
    final pages = <Widget>[
      if (role == 'seller')
        SellerPage(client: widget.client, user: widget.user),
      if (role == 'buyer')
        BuyerPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      if (role == 'buyer') OrdersPage(client: widget.client),
      if (role == 'seller')
        BuyerPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      if (role == 'seller') OrdersPage(client: widget.client),
      if (role == 'deliverer')
        DeliveryPage(
          client: widget.client,
          user: widget.user,
          onUserChanged: widget.onUserChanged,
        ),
      ChatPage(
        client: widget.client,
        user: widget.user,
        onUnreadCountChanged: updateUnreadChatCount,
      ),
      ProfilePage(
        client: widget.client,
        token: widget.token,
        user: widget.user,
        onUserChanged: widget.onUserChanged,
        onSignOut: widget.onSignOut,
        notificationsEnabled: widget.notificationsEnabled,
        onNotificationsEnabledChanged: widget.onNotificationsEnabledChanged,
        onRefreshNotifications: widget.onRefreshNotifications,
        onShowTestNotification: widget.onShowTestNotification,
      ),
    ];
    final destinations = <NavigationDestination>[
      if (role == 'seller')
        const NavigationDestination(
          icon: Icon(Icons.add_business_outlined),
          selectedIcon: Icon(Icons.add_business),
          label: 'Sell',
        ),
      if (role == 'buyer')
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Shop',
        ),
      if (role == 'buyer')
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
      if (role == 'seller')
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Shop',
        ),
      if (role == 'seller')
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
      if (role == 'deliverer')
        const NavigationDestination(
          icon: Icon(Icons.delivery_dining_outlined),
          selectedIcon: Icon(Icons.delivery_dining),
          label: 'Deliver',
        ),
      NavigationDestination(
        icon: chatDestinationIcon(Icons.chat_bubble_outline),
        selectedIcon: chatDestinationIcon(Icons.chat_bubble),
        label: 'Chat',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              role == 'buyer'
                  ? kAppName
                  : '${role[0].toUpperCase()}${role.substring(1)} Hub',
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: Text(
                widget.notificationCount > 99
                    ? '99+'
                    : '${widget.notificationCount}',
              ),
              isLabelVisible: widget.notificationCount > 0,
              child: IconButton(
                tooltip: tx('Notifications', 'Arifa'),
                onPressed: openNotificationInbox,
                icon: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: appSurfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: appShadowColor(context, lightAlpha: 0.08, darkAlpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: index,
          backgroundColor: Colors.transparent,
          indicatorColor: appPrimarySoftColor(context),
          destinations: destinations,
          onDestinationSelected: (v) {
            setState(() => index = v);
            widget.onSelectedIndexChanged(v);
          },
        ),
      ),
    );
  }
}
