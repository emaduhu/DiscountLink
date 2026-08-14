part of '../../../../../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.client,
    required this.token,
    required this.user,
    required this.onUserChanged,
    required this.onSignOut,
    required this.notificationsEnabled,
    required this.onNotificationsEnabledChanged,
    required this.onRefreshNotifications,
    required this.onShowTestNotification,
  });
  final ApiClient client;
  final String token;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  final Future<void> Function() onSignOut;
  final bool notificationsEnabled;
  final Future<void> Function(bool enabled) onNotificationsEnabledChanged;
  final Future<String?> Function() onRefreshNotifications;
  final VoidCallback onShowTestNotification;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
