part of '../../../../../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.client,
    required this.token,
    required this.user,
    required this.initialIndex,
    required this.onSelectedIndexChanged,
    required this.onUserChanged,
    required this.onSignOut,
    required this.notificationCount,
    required this.onNotificationInboxChanged,
    required this.notificationsEnabled,
    required this.onNotificationsEnabledChanged,
    required this.onRefreshNotifications,
    required this.onShowTestNotification,
  });
  final ApiClient client;
  final String token;
  final Map<String, dynamic> user;
  final int initialIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
  final int notificationCount;
  final Future<void> Function() onNotificationInboxChanged;
  final bool notificationsEnabled;
  final Future<void> Function(bool enabled) onNotificationsEnabledChanged;
  final Future<String?> Function() onRefreshNotifications;
  final VoidCallback onShowTestNotification;
  @override
  State<HomePage> createState() => _HomePageState();
}
