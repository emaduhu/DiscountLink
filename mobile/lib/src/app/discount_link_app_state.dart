part of '../../main.dart';

class _DiscountLinkAppState extends State<DiscountLinkApp> {
  final client = ApiClient(apiBaseUrl);
  final updateEnforcer = MandatoryUpdateUpgrader(
    durationUntilAlertAgain: Duration.zero,
  );
  Map<String, dynamic>? user;
  bool showSplash = true;
  bool restoringStartupState = true;
  int restoredHomeIndex = 0;
  StreamSubscription<String>? fcmTokenSubscription;
  StreamSubscription<RemoteMessage>? foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? notificationOpenedSubscription;
  OverlayEntry? foregroundNotificationEntry;
  Timer? foregroundNotificationTimer;
  bool checkedInitialNotification = false;
  bool pushNotificationsEnabled = true;
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    restoreStartupState();
    loadNotificationPreference();
    loadNotificationCount();
  }

  Future<void> restoreStartupState() async {
    PersistedSession? session;
    var hasSeenSplash = false;
    var homeIndex = 0;
    try {
      session = await sessionPersistence.restore();
      hasSeenSplash = await sessionPersistence.hasSeenSplash();
      homeIndex = await sessionPersistence.homeIndex() ?? 0;
    } catch (_) {}

    final restoredSession = session;
    if (!mounted) return;
    setState(() {
      if (restoredSession != null) {
        client.token = restoredSession.token;
        user = restoredSession.user;
        showSplash = false;
      } else {
        showSplash = !hasSeenSplash;
      }
      restoredHomeIndex = homeIndex;
      restoringStartupState = false;
    });

    if (restoredSession != null) {
      registerNotifications();
    }
  }

  Future<void> loadNotificationPreference() async {
    final enabled = await notificationPreferences.isEnabled();
    if (!mounted) return;
    setState(() => pushNotificationsEnabled = enabled);
  }

  Future<void> loadNotificationCount() async {
    final count = await notificationInbox.count();
    if (!mounted) return;
    setState(() => notificationCount = count);
  }

  Future<void> recordNotificationMessage(
    RemoteMessage message, {
    required String title,
    required String body,
  }) async {
    await recordStoredNotification(
      storedNotificationFromRemoteMessage(message, title: title, body: body),
    );
  }

  Future<void> recordStoredNotification(StoredNotification notification) async {
    final nextCount = await notificationInbox.add(notification);
    if (!mounted) return;
    setState(() => notificationCount = nextCount);
  }

  ({String title, String body}) notificationContent(RemoteMessage message) {
    final title = (message.notification?.title ?? '').trim();
    final body = (message.notification?.body ?? '').trim();
    final fallbackCode = '${message.data['delivery_code'] ?? ''}'.trim();
    final fallbackBody = fallbackCode.isNotEmpty
        ? 'Your delivery code is $fallbackCode.'
        : '';
    return (
      title: title.isNotEmpty ? title : kAppName,
      body: body.isNotEmpty ? body : fallbackBody,
    );
  }

  void signedIn(String token, Map<String, dynamic> signedUser) {
    setState(() {
      client.token = token;
      user = signedUser;
      showSplash = false;
    });
    unawaited(saveCurrentSession());
    biometricAuth.isEnabledFor(signedUser).then((enabled) {
      if (enabled) {
        biometricAuth.enable(token: token, user: signedUser);
      }
    });
    registerNotifications();
  }

  Future<void> saveCurrentSession() async {
    final token = client.token;
    final signedUser = user;
    if (token == null || token.isEmpty || signedUser == null) return;

    try {
      await sessionPersistence.save(token: token, user: signedUser);
    } catch (_) {}
  }

  void updateSignedUser(Map<String, dynamic> updatedUser) {
    setState(() => user = updatedUser);
    unawaited(saveCurrentSession());
  }

  void persistHomeIndex(int index) {
    restoredHomeIndex = index;
    unawaited(saveHomeIndex(index));
  }

  void continueFromSplash() {
    setState(() => showSplash = false);
    unawaited(markSplashSeen());
  }

  Future<void> saveHomeIndex(int index) async {
    try {
      await sessionPersistence.setHomeIndex(index);
    } catch (_) {}
  }

  Future<void> markSplashSeen() async {
    try {
      await sessionPersistence.setSplashSeen();
    } catch (_) {}
  }

  Future<void> registerNotifications() async {
    try {
      final enabled = await notificationPreferences.isEnabled();
      if (!enabled) {
        await unregisterDeviceNotifications(persistPreference: false);
        return;
      }
      if (mounted && !pushNotificationsEnabled) {
        setState(() => pushNotificationsEnabled = true);
      }
      await ensureFirebaseInitialized(feature: 'push notifications');
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await unregisterDeviceNotifications(persistPreference: false);
        return;
      }
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
        showForegroundNotification,
      );
      notificationOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
          .listen((message) => unawaited(openNotificationMessage(message)));
      if (!checkedInitialNotification) {
        checkedInitialNotification = true;
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          unawaited(openNotificationMessage(initialMessage));
        }
      }
      final token = await firebaseMessagingToken();
      if (token != null) {
        await client.post('/me/fcm-token', {
          'fcm_token': token,
        }, showBlockingLoader: false);
      }
      fcmTokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          if (client.token == null || !pushNotificationsEnabled) {
            return;
          }
          try {
            await client.post('/me/fcm-token', {
              'fcm_token': token,
            }, showBlockingLoader: false);
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  Future<void> unregisterDeviceNotifications({
    required bool persistPreference,
  }) async {
    if (persistPreference) {
      await notificationPreferences.setEnabled(false);
    }
    if (mounted && pushNotificationsEnabled) {
      setState(() => pushNotificationsEnabled = false);
    }
    hideForegroundNotificationBanner();
    final tokenSubscription = fcmTokenSubscription;
    final foregroundSubscription = foregroundMessageSubscription;
    final openedSubscription = notificationOpenedSubscription;
    fcmTokenSubscription = null;
    foregroundMessageSubscription = null;
    notificationOpenedSubscription = null;
    try {
      await tokenSubscription?.cancel();
    } catch (_) {}
    try {
      await foregroundSubscription?.cancel();
    } catch (_) {}
    try {
      await openedSubscription?.cancel();
    } catch (_) {}
    try {
      if (client.token != null) {
        await client.post('/me/fcm-token', {
          'fcm_token': null,
        }, showBlockingLoader: false);
      }
    } catch (_) {}
    try {
      await ensureFirebaseInitialized(feature: 'push notifications');
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    if (value) {
      await notificationPreferences.setEnabled(true);
      if (mounted) setState(() => pushNotificationsEnabled = true);
      await registerNotifications();
    } else {
      await unregisterDeviceNotifications(persistPreference: true);
    }
  }

  Future<String?> refreshPushNotifications() async {
    await notificationPreferences.setEnabled(true);
    if (mounted && !pushNotificationsEnabled) {
      setState(() => pushNotificationsEnabled = true);
    }
    try {
      await ensureFirebaseInitialized(feature: 'push notifications');
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await registerNotifications();
    return firebaseMessagingToken();
  }

  void showTestNotification() {
    final title = tx('Notifications are ready', 'Arifa ziko tayari');
    final body = tx(
      'DiscountLink can show order, chat, and delivery updates on this device.',
      'DiscountLink inaweza kuonyesha taarifa za oda, soga, na usafirishaji kwenye kifaa hiki.',
    );
    final now = DateTime.now();
    unawaited(
      recordStoredNotification(
        StoredNotification(
          id: sha1
              .convert(utf8.encode('test|${now.toIso8601String()}'))
              .toString(),
          title: title,
          body: body,
          receivedAt: now,
          data: const {'type': 'test'},
        ),
      ),
    );
    showTopNotificationBanner(title: title, body: body, isChat: false);
  }

  void showForegroundNotification(RemoteMessage message) {
    if (client.token == null || !pushNotificationsEnabled) return;

    final content = notificationContent(message);
    final effectiveTitle = content.title;
    final effectiveBody = content.body;
    if (effectiveTitle.isEmpty && effectiveBody.isEmpty) return;
    unawaited(
      recordNotificationMessage(
        message,
        title: effectiveTitle,
        body: effectiveBody,
      ),
    );

    // Apple displays the native foreground banner configured above. Android
    // does not, so surface the received FCM notification inside the app.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return;
    }

    final type = '${message.data['type'] ?? ''}'.trim();
    final route = '${message.data['route'] ?? ''}'.trim();
    final isChat = type == 'chat_message';
    final isProduct =
        route == 'product' ||
        type == 'product_added' ||
        type == 'product_campaign';
    final unreadCount =
        int.tryParse('${message.data['unread_count'] ?? 0}') ?? 0;

    showTopNotificationBanner(
      title: effectiveTitle,
      body: effectiveBody,
      isChat: isChat,
      isProduct: isProduct,
      unreadCount: isChat ? unreadCount : 0,
      onTap: (isChat || isProduct)
          ? () => unawaited(openNotificationMessage(message))
          : null,
    );
  }

  void showTopNotificationBanner({
    required String title,
    required String body,
    required bool isChat,
    bool isProduct = false,
    int unreadCount = 0,
    VoidCallback? onTap,
  }) {
    final overlay = appNavigatorKey.currentState?.overlay;
    final context = appNavigatorKey.currentContext;
    if (overlay == null || context == null) {
      showFallbackNotification(title, body);
      return;
    }

    foregroundNotificationTimer?.cancel();
    foregroundNotificationEntry?.remove();
    foregroundNotificationEntry = OverlayEntry(
      builder: (context) {
        final top = MediaQuery.paddingOf(context).top + 10;
        return Positioned(
          top: top,
          left: 12,
          right: 12,
          child: ResponsiveCenter(
            maxWidth: kResponsiveNotificationMaxWidth,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -18, end: 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) =>
                  Transform.translate(offset: Offset(0, offset), child: child),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    hideForegroundNotificationBanner();
                    onTap?.call();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: appSurfaceColor(context),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: appShadowColor(
                            context,
                            lightAlpha: 0.18,
                            darkAlpha: 0.30,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: appPrimarySoftColor(context),
                          child: Icon(
                            isChat
                                ? Icons.chat_bubble_outline
                                : isProduct
                                ? Icons.local_offer_outlined
                                : Icons.notifications_active_outlined,
                            color: kPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: appTitleColor(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 1) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kPrimaryLightColor,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                          color: kPrimaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Text(
                                    'now',
                                    style: TextStyle(
                                      color: appMutedTextColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: appMutedTextColor(context),
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(foregroundNotificationEntry!);
    foregroundNotificationTimer = Timer(
      const Duration(seconds: 6),
      hideForegroundNotificationBanner,
    );
  }

  Future<void> openNotificationMessage(RemoteMessage message) async {
    if (!pushNotificationsEnabled) return;
    final content = notificationContent(message);
    final title = content.title;
    final body = content.body;
    if (title.isNotEmpty || body.isNotEmpty) {
      unawaited(recordNotificationMessage(message, title: title, body: body));
    }
    final data = message.data;
    final route = '${data['route'] ?? ''}'.trim();
    final type = '${data['type'] ?? ''}'.trim();
    if (route == 'chat' || type == 'chat_message') {
      await openChatFromNotification('${data['conversation_id'] ?? ''}');
      return;
    }
    if (route == 'product' ||
        type == 'product_added' ||
        type == 'product_campaign') {
      await openProductFromNotification('${data['product_id'] ?? ''}');
    }
  }

  Future<NavigatorState?> notificationNavigator() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) return navigator;
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    return appNavigatorKey.currentState;
  }

  Future<void> openChatFromNotification(String conversationId) async {
    final id = conversationId.trim();
    final signedUser = user;
    final navigator = await notificationNavigator();
    if (id.isEmpty ||
        client.token == null ||
        signedUser == null ||
        navigator == null) {
      return;
    }

    try {
      final response = await client.get('/conversations/$id/messages', {
        'page': '1',
        'per_page': '50',
      });
      final loadedConversation = response['conversation'];
      if (loadedConversation is! Map) {
        return;
      }
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(
            client: client,
            user: signedUser,
            conversation: Map<String, dynamic>.from(loadedConversation),
          ),
        ),
      );
    } catch (error) {
      showFallbackNotification(
        tx('Could not open chat', 'Imeshindikana kufungua soga'),
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> openProductFromNotification(String productId) async {
    final id = int.tryParse(productId.trim());
    final signedUser = user;
    final navigator = await notificationNavigator();
    if (id == null ||
        client.token == null ||
        signedUser == null ||
        navigator == null) {
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailsPage(client: client, user: signedUser, productId: id),
      ),
    );
  }

  void hideForegroundNotificationBanner() {
    foregroundNotificationTimer?.cancel();
    foregroundNotificationTimer = null;
    foregroundNotificationEntry?.remove();
    foregroundNotificationEntry = null;
  }

  void showFallbackNotification(String title, String body) {
    final text = [title, if (body.isNotEmpty) body].join('\n');
    final messenger = appScaffoldMessengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
  }

  Future<void> signedOut() async {
    await networkActivity.run(() async {
      await unregisterDeviceNotifications(persistPreference: false);
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        client.token = null;
        user = null;
        showSplash = false;
        restoredHomeIndex = 0;
      });
      try {
        await sessionPersistence.clearSession();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    hideForegroundNotificationBanner();
    updateEnforcer.dispose();
    fcmTokenSubscription?.cancel();
    foregroundMessageSubscription?.cancel();
    notificationOpenedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, _, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, themeMode, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          title: kAppName,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => GlobalNetworkLoadingOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          theme: discountLinkTheme(Brightness.light),
          darkTheme: discountLinkTheme(Brightness.dark),
          themeMode: themeMode,
          home: UpgradeAlert(
            upgrader: updateEnforcer,
            barrierDismissible: false,
            shouldPopScope: () => false,
            showIgnore: false,
            showLater: false,
            showReleaseNotes: false,
            child: restoringStartupState
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : showSplash
                ? SplashPage(onContinue: continueFromSplash)
                : user == null
                ? LoginPage(client: client, onSignedIn: signedIn)
                : HomePage(
                    client: client,
                    token: client.token ?? '',
                    user: user!,
                    initialIndex: restoredHomeIndex,
                    onSelectedIndexChanged: persistHomeIndex,
                    onUserChanged: updateSignedUser,
                    onSignOut: signedOut,
                    notificationCount: notificationCount,
                    onNotificationInboxChanged: loadNotificationCount,
                    notificationsEnabled: pushNotificationsEnabled,
                    onNotificationsEnabledChanged: setPushNotificationsEnabled,
                    onRefreshNotifications: refreshPushNotifications,
                    onShowTestNotification: showTestNotification,
                  ),
          ),
        ),
      ),
    );
  }
}
