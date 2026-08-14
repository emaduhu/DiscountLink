part of '../../../../../main.dart';

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final code = TextEditingController();
  final emailCode = TextEditingController();
  final newPhone = TextEditingController();
  bool sent = false;
  bool emailSent = false;
  bool loading = false;
  bool nameLoading = false;
  bool phoneChangeLoading = false;
  bool emailLoading = false;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool biometricLoading = false;
  String biometricMethodLabel = 'biometrics';
  bool notificationsLoading = false;
  bool accountDeleteLoading = false;
  String otpProvider = 'beem';
  AuthorizationStatus? notificationPermissionStatus;
  String? notificationDeviceToken;
  String? notificationError;
  String? firebaseVerificationId;
  String? visiblePhoneCode;
  String? localPendingPhone;
  final profileOverviewKey = GlobalKey();
  final profileAccountKey = GlobalKey();
  final profileNotificationsKey = GlobalKey();
  final profileEmailKey = GlobalKey();
  final profilePhoneKey = GlobalKey();
  final profileDeleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final codes = widget.user['_verification_codes'];
    if (codes is Map) {
      visiblePhoneCode = codes['phone']?.toString();
      if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
        code.text = visiblePhoneCode!;
        sent = true;
      }
    }
    name.text = '${widget.user['name'] ?? ''}'.trim();
    newPhone.text =
        '${widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'.trim();
    localPendingPhone = '${widget.user['pending_phone'] ?? ''}'.trim();
    loadProvider();
    loadBiometricState();
    loadNotificationState();
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    emailCode.dispose();
    newPhone.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPhone =
        '${widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'.trim();
    final previousPhone =
        '${oldWidget.user['pending_phone'] ?? oldWidget.user['phone'] ?? ''}'
            .trim();
    if (nextPhone != previousPhone && newPhone.text.trim() == previousPhone) {
      newPhone.text = nextPhone;
    }
    final nextName = '${widget.user['name'] ?? ''}'.trim();
    final previousName = '${oldWidget.user['name'] ?? ''}'.trim();
    if (nextName != previousName && name.text.trim() == previousName) {
      name.text = nextName;
    }
    localPendingPhone = '${widget.user['pending_phone'] ?? ''}'.trim();
    if (oldWidget.notificationsEnabled != widget.notificationsEnabled) {
      loadNotificationState();
    }
  }

  Future<void> loadProvider() async {
    try {
      final r = await widget.client.get('/otp/provider');
      if (mounted) setState(() => otpProvider = r['provider'] as String);
    } catch (_) {}
  }

  Future<void> loadBiometricState() async {
    final available = await biometricAuth.canUseBiometrics();
    final enabled = await biometricAuth.isEnabledFor(widget.user);
    final methodLabel = await biometricAuth.methodLabel();
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricEnabled = enabled;
      biometricMethodLabel = methodLabel;
    });
  }

  Future<void> loadNotificationState({
    bool showLoading = false,
    bool? enabledOverride,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        notificationsLoading = true;
        notificationError = null;
      });
    }
    try {
      await ensureFirebaseInitialized(feature: 'push notifications');
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      final enabled = enabledOverride ?? widget.notificationsEnabled;
      final token =
          enabled && settings.authorizationStatus != AuthorizationStatus.denied
          ? await firebaseMessagingToken()
          : null;
      if (!mounted) return;
      setState(() {
        notificationPermissionStatus = settings.authorizationStatus;
        notificationDeviceToken = token;
        notificationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        notificationPermissionStatus = null;
        notificationDeviceToken = null;
        notificationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (showLoading && mounted) {
        setState(() => notificationsLoading = false);
      }
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    setState(() {
      notificationsLoading = true;
      notificationError = null;
    });
    try {
      await widget.onNotificationsEnabledChanged(value);
      await loadNotificationState(enabledOverride: value);
      if (!mounted) return;
      final blocked =
          notificationPermissionStatus == AuthorizationStatus.denied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value && blocked
                ? tx(
                    'Notifications are blocked in device settings.',
                    'Arifa zimezuiwa kwenye mipangilio ya kifaa.',
                  )
                : value
                ? tx('Notifications enabled.', 'Arifa zimewashwa.')
                : tx(
                    'Notifications muted on this device.',
                    'Arifa zimezimwa kwenye kifaa hiki.',
                  ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => notificationError = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => notificationsLoading = false);
    }
  }

  Future<void> refreshNotifications() async {
    setState(() {
      notificationsLoading = true;
      notificationError = null;
    });
    try {
      final token = await widget.onRefreshNotifications();
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (!mounted) return;
      setState(() {
        notificationPermissionStatus = settings.authorizationStatus;
        notificationDeviceToken = token;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            token == null
                ? tx(
                    'Notifications are enabled, but the device token is not ready yet.',
                    'Arifa zimewashwa, lakini tokeni ya kifaa bado haiko tayari.',
                  )
                : tx(
                    'Notification device token refreshed.',
                    'Tokeni ya arifa ya kifaa imesasishwa.',
                  ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => notificationError = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => notificationsLoading = false);
    }
  }

  String notificationPermissionLabel() {
    return switch (notificationPermissionStatus) {
      AuthorizationStatus.authorized => tx('Allowed', 'Zimeruhusiwa'),
      AuthorizationStatus.provisional => tx('Provisional', 'Ruhusa ya muda'),
      AuthorizationStatus.denied => tx('Blocked', 'Zimezuiwa'),
      AuthorizationStatus.notDetermined => tx('Not requested', 'Hazijaombwa'),
      null => tx('Unknown', 'Haijulikani'),
    };
  }

  String notificationSummary() {
    final error = notificationError;
    if (error != null && error.isNotEmpty) return error;
    if (!widget.notificationsEnabled) {
      return tx(
        'This device is muted. DiscountLink will remove its push token from your account.',
        'Kifaa hiki kimezimwa arifa. DiscountLink itaondoa tokeni ya arifa kwenye akaunti yako.',
      );
    }
    if (notificationPermissionStatus == AuthorizationStatus.denied) {
      return tx(
        'Notifications are blocked in device settings. Allow notifications there, then refresh.',
        'Arifa zimezuiwa kwenye mipangilio ya kifaa. Ziruhusu huko, kisha sasisha.',
      );
    }
    if (notificationDeviceToken == null) {
      return tx(
        'Waiting for this device to receive a Firebase notification token.',
        'Inasubiri kifaa hiki kipokee tokeni ya arifa ya Firebase.',
      );
    }
    return tx(
      'This device is registered for order, chat, and delivery notifications.',
      'Kifaa hiki kimesajiliwa kwa arifa za oda, soga, na usafirishaji.',
    );
  }

  Color notificationStatusColor() {
    if (notificationError != null ||
        notificationPermissionStatus == AuthorizationStatus.denied) {
      return Colors.red;
    }
    if (!widget.notificationsEnabled) return kTextColor;
    if (notificationDeviceToken != null) return Colors.green;
    return kPrimaryColor;
  }

  Future<void> setBiometricEnabled(bool value) async {
    setState(() => biometricLoading = true);
    try {
      if (value) {
        if (widget.token.isEmpty) {
          throw Exception('Sign in again before enabling biometric login.');
        }
        final method = await biometricAuth.methodLabel();
        final ok = await biometricAuth.authenticate(
          'Confirm with $method to enable biometric login for Discount Link',
        );
        if (!ok) return;
        await biometricAuth.enable(token: widget.token, user: widget.user);
      } else {
        await biometricAuth.disable();
      }
      if (!mounted) return;
      setState(() => biometricEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '$biometricMethodLabel login enabled.'
                : '$biometricMethodLabel login disabled.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => biometricLoading = false);
    }
  }

  Future<void> deleteAccount() async {
    var confirmText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canDelete = confirmText.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Text(tx('Delete account?', 'Futa akaunti?')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tx(
                    'Your account will be deleted and you will be signed out. You will need support to restore access.',
                    'Akaunti yako itafutwa na utatolewa. Utahitaji msaada kurejesha ufikiaji.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: tx(
                      'Type DELETE to confirm',
                      'Andika DELETE kuthibitisha',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(() {
                    confirmText = value;
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tx('Cancel', 'Ghairi')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: canDelete
                    ? () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context, true);
                      }
                    : null,
                child: Text(tx('Delete account', 'Futa akaunti')),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    setState(() => accountDeleteLoading = true);
    try {
      await widget.client.post('/me/delete', {});
      await biometricAuth.disable();
      if (!mounted) return;
      await widget.onSignOut();
      return;
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => accountDeleteLoading = false);
  }

  Future<void> saveName() async {
    final nextName = name.text.trim();
    if (nextName.isEmpty) {
      showError(
        context,
        Exception(tx('Enter your full name.', 'Weka jina lako kamili.')),
      );
      return;
    }

    setState(() => nameLoading = true);
    try {
      final r = await widget.client.put('/me', {'name': nextName});
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('Name updated.', 'Jina limesasishwa.'))),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => nameLoading = false);
    }
  }

  Future<void> sendOtp() async {
    setState(() => loading = true);
    try {
      final phone = requireTwelveDigitPhone(verificationPhone());
      if (phone.isEmpty) {
        throw Exception(
          tx('Add a phone number first.', 'Weka namba ya simu kwanza.'),
        );
      }
      if (otpProvider == 'firebase') {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone.startsWith('+') ? phone : '+$phone',
          verificationCompleted: (credential) async {
            final firebaseUser = await FirebaseAuth.instance
                .signInWithCredential(credential);
            final idToken = await firebaseUser.user?.getIdToken();
            if (idToken != null) {
              await verifyFirebaseToken(idToken, phone);
            }
          },
          verificationFailed: (error) {
            if (mounted) showError(context, error.message ?? error);
          },
          codeSent: (verificationId, _) {
            if (mounted) {
              setState(() {
                firebaseVerificationId = verificationId;
                sent = true;
              });
            }
          },
          codeAutoRetrievalTimeout: (verificationId) {
            firebaseVerificationId = verificationId;
          },
        );
      } else {
        final r = await widget.client.post('/otp/request', {'phone': phone});
        if (r['phone_otp_sent'] == false) {
          throw Exception(
            r['message'] ??
                tx(
                  'OTP could not be sent. Try again shortly.',
                  'OTP haikuweza kutumwa. Jaribu tena baada ya muda.',
                ),
          );
        }
        if (mounted) {
          setState(() {
            visiblePhoneCode = r['phone_code']?.toString();
            if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
              code.text = visiblePhoneCode!;
            }
            sent = true;
          });
        }
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyFirebaseToken(
    String idToken, [
    String? verifiedPhone,
  ]) async {
    final r = await widget.client.post('/otp/verify', {
      'phone': verifiedPhone ?? requireTwelveDigitPhone(verificationPhone()),
      'firebase_id_token': idToken,
    });
    widget.onUserChanged(r['user'] as Map<String, dynamic>);
    if (mounted) {
      setState(() {
        localPendingPhone = null;
        sent = false;
        visiblePhoneCode = null;
        code.clear();
      });
    }
  }

  Future<void> verifyOtp() async {
    setState(() => loading = true);
    try {
      final phone = requireTwelveDigitPhone(verificationPhone());
      if (otpProvider == 'firebase') {
        final verificationId = firebaseVerificationId;
        if (verificationId == null) {
          throw Exception('Request the Firebase code first.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code.text.trim(),
        );
        final firebaseUser = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final idToken = await firebaseUser.user?.getIdToken();
        if (idToken == null) throw Exception('Firebase token was not issued.');
        await verifyFirebaseToken(idToken, phone);
      } else {
        final r = await widget.client.post('/otp/verify', {
          'phone': phone,
          'code': code.text.trim(),
        });
        widget.onUserChanged(r['user'] as Map<String, dynamic>);
        if (mounted) {
          setState(() {
            localPendingPhone = null;
            sent = false;
            visiblePhoneCode = null;
            code.clear();
          });
        }
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String verificationPhone() =>
      '${localPendingPhone?.isNotEmpty == true ? localPendingPhone : widget.user['pending_phone'] ?? widget.user['phone'] ?? ''}'
          .trim();

  Future<void> startPhoneChange() async {
    final phone = normalizePhoneInput(newPhone.text);
    if (phone.isEmpty) {
      showError(
        context,
        Exception(
          tx('Enter the new phone number.', 'Weka namba mpya ya simu.'),
        ),
      );
      return;
    }
    try {
      requireTwelveDigitPhone(phone);
    } catch (error) {
      showError(context, error);
      return;
    }

    setState(() => phoneChangeLoading = true);
    try {
      final r = await widget.client.put('/me', {'phone': phone});
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        localPendingPhone = phone;
        visiblePhoneCode = r['phone_code']?.toString();
        if (visiblePhoneCode != null && visiblePhoneCode!.isNotEmpty) {
          code.text = visiblePhoneCode!;
        } else {
          code.clear();
        }
        sent = r['phone_otp_sent'] == true || visiblePhoneCode != null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r['message'] ?? tx('Phone change started.', 'Mabadiliko ya simu yameanza.')}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => phoneChangeLoading = false);
    }
  }

  Future<void> sendEmailOtp() async {
    setState(() => emailLoading = true);
    try {
      final r = await widget.client.post('/email/otp/request', {});
      final emailWasSent = r['email_otp_sent'] == true;
      if (!emailWasSent) {
        throw Exception(
          r['message'] ??
              tx(
                'Email verification code could not be sent. Check the address and try again.',
                'Kodi ya uthibitishaji wa barua pepe haikuweza kutumwa. Hakiki anwani kisha jaribu tena.',
              ),
        );
      }
      if (mounted) {
        setState(() {
          emailSent = true;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => emailLoading = false);
    }
  }

  Future<void> verifyEmailOtp() async {
    setState(() => emailLoading = true);
    try {
      final r = await widget.client.post('/email/otp/verify', {
        'code': emailCode.text.trim(),
      });
      widget.onUserChanged(r['user'] as Map<String, dynamic>);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => emailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneVerified = widget.user['phone_verified_at'] != null;
    final emailVerified = widget.user['email_verified_at'] != null;
    final pendingPhone =
        '${localPendingPhone?.isNotEmpty == true ? localPendingPhone : widget.user['pending_phone'] ?? ''}'
            .trim();
    final hasPendingPhone = pendingPhone.isNotEmpty;
    return ResponsiveSectionListView(
      menuTitle: tx('Profile menu', 'Menyu ya wasifu'),
      menuItems: [
        SectionMenuItem(
          label: tx('Overview', 'Muhtasari'),
          icon: Icons.account_circle_outlined,
          key: profileOverviewKey,
        ),
        SectionMenuItem(
          label: tx('Account', 'Akaunti'),
          icon: Icons.manage_accounts_outlined,
          key: profileAccountKey,
        ),
        SectionMenuItem(
          label: tx('Notifications', 'Arifa'),
          icon: Icons.notifications_outlined,
          key: profileNotificationsKey,
        ),
        SectionMenuItem(
          label: tx('Email', 'Barua pepe'),
          icon: Icons.email_outlined,
          key: profileEmailKey,
        ),
        SectionMenuItem(
          label: tx('Phone', 'Simu'),
          icon: Icons.phone_android_outlined,
          key: profilePhoneKey,
        ),
        SectionMenuItem(
          label: tx('Delete', 'Futa'),
          icon: Icons.delete_outline,
          key: profileDeleteKey,
        ),
      ],
      maxWidth: kResponsiveContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SurfacePanel(
          key: profileOverviewKey,
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: kPrimaryLightColor,
                child: Text(
                  initials(widget.user['name'] ?? 'DL'),
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['name'] ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.user['role']} - ${widget.user['email'] ?? ''}',
                      style: const TextStyle(color: kTextColor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label: emailVerified
                              ? 'Email verified'
                              : 'Email pending',
                          color: emailVerified ? Colors.green : kPrimaryColor,
                        ),
                        StatusPill(
                          label: phoneVerified
                              ? 'Phone verified'
                              : 'Phone pending',
                          color: phoneVerified ? Colors.green : kPrimaryColor,
                        ),
                        StatusPill(
                          label: widget.user['is_active'] == true
                              ? 'Active'
                              : 'Blocked',
                          color: widget.user['is_active'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          key: profileAccountKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LanguageSwitch(),
              const Divider(height: 24),
              Field(
                controller: name,
                label: tx('Full name', 'Jina kamili'),
                icon: Icons.person_outline,
              ),
              FilledButton.icon(
                onPressed: nameLoading ? null : saveName,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  nameLoading
                      ? tx('Saving...', 'Inahifadhi...')
                      : tx('Save name', 'Hifadhi jina'),
                ),
              ),
              const Divider(height: 24),
              ProfileLine(
                icon: Icons.email_outlined,
                title: tx('Email', 'Barua pepe'),
                value: widget.user['email'] ?? '',
              ),
              ProfileLine(
                icon: Icons.phone_outlined,
                title: tx('Phone', 'Simu'),
                value: widget.user['phone'] ?? '',
              ),
              if (hasPendingPhone)
                ProfileLine(
                  icon: Icons.pending_actions_outlined,
                  title: tx('Pending phone', 'Simu inayosubiri'),
                  value: pendingPhone,
                ),
              ProfileLine(
                icon: Icons.badge_outlined,
                title: tx('NIDA number', 'Namba ya NIDA'),
                value: widget.user['nida_number'] ?? '',
              ),
              ProfileLine(
                icon: Icons.place_outlined,
                title: tx('Address', 'Anwani'),
                value: widget.user['address'] ?? '',
              ),
              const Divider(height: 24),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: biometricEnabled,
                  onChanged: biometricAvailable && !biometricLoading
                      ? setBiometricEnabled
                      : null,
                  secondary: Icon(
                    biometricMethodLabel == 'Face ID'
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  title: Text(
                    tx(
                      '$biometricMethodLabel login',
                      'Kuingia kwa $biometricMethodLabel',
                    ),
                  ),
                  subtitle: Text(
                    biometricAvailable
                        ? tx(
                            'Use $biometricMethodLabel on this device.',
                            'Tumia $biometricMethodLabel kwenye kifaa hiki.',
                          )
                        : tx(
                            'Set up $biometricMethodLabel on this device first.',
                            'Sanidi $biometricMethodLabel kwenye kifaa hiki kwanza.',
                          ),
                  ),
                ),
              ),
              if (biometricLoading) const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          key: profileNotificationsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: kPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx('Notification management', 'Usimamizi wa arifa'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusPill(
                    label: widget.notificationsEnabled
                        ? tx('On', 'Zimewashwa')
                        : tx('Muted', 'Zimezimwa'),
                    color: notificationStatusColor(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notificationSummary(),
                style: const TextStyle(color: kTextColor, height: 1.35),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label:
                        '${tx('Permission', 'Ruhusa')}: ${notificationPermissionLabel()}',
                    color: notificationStatusColor(),
                  ),
                  StatusPill(
                    label: notificationDeviceToken == null
                        ? tx('No device token', 'Hakuna tokeni ya kifaa')
                        : tx(
                            'Device token ready',
                            'Tokeni ya kifaa iko tayari',
                          ),
                    color: notificationDeviceToken == null
                        ? kTextColor
                        : Colors.green,
                  ),
                ],
              ),
              const Divider(height: 24),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.notificationsEnabled,
                  onChanged: notificationsLoading
                      ? null
                      : setNotificationsEnabled,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: Text(
                    tx(
                      'Push notifications on this device',
                      'Arifa za push kwenye kifaa hiki',
                    ),
                  ),
                  subtitle: Text(
                    tx(
                      'Turn off to unregister this phone from push notifications.',
                      'Zima ili kuondoa simu hii kwenye arifa za push.',
                    ),
                  ),
                ),
              ),
              if (notificationsLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: notificationsLoading
                        ? null
                        : () => loadNotificationState(showLoading: true),
                    icon: const Icon(Icons.info_outline),
                    label: Text(tx('Check status', 'Angalia hali')),
                  ),
                  FilledButton.icon(
                    onPressed: notificationsLoading
                        ? null
                        : refreshNotifications,
                    icon: const Icon(Icons.sync),
                    label: Text(tx('Refresh token', 'Sasisha tokeni')),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        widget.notificationsEnabled && !notificationsLoading
                        ? widget.onShowTestNotification
                        : null,
                    icon: const Icon(Icons.notification_add_outlined),
                    label: Text(tx('Test banner', 'Jaribu bango')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          key: profileEmailKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                emailVerified
                    ? tx('Email verified', 'Barua pepe imethibitishwa')
                    : tx('Verify email', 'Thibitisha barua pepe'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (!emailVerified) ...[
                VerificationStatusLine(
                  sent: emailSent,
                  visibleCode: null,
                  destination: widget.user['email'] ?? '',
                  pendingText: tx(
                    'Email is pending. Send a code to verify this account.',
                    'Barua pepe haijathibitishwa. Tuma kodi kuthibitisha akaunti.',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: emailLoading ? null : sendEmailOtp,
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: Text(
                    emailSent
                        ? tx('Email code sent again', 'Kodi imetumwa tena')
                        : tx('Send email code', 'Tuma kodi ya barua pepe'),
                  ),
                ),
                Field(
                  controller: emailCode,
                  label: tx('Six digit email code', 'Kodi ya barua pepe'),
                  icon: Icons.password,
                  keyboard: TextInputType.number,
                ),
              ] else
                VerificationStatusLine(
                  sent: true,
                  visibleCode: null,
                  destination: widget.user['email'] ?? '',
                  pendingText: tx(
                    'Email verification is complete.',
                    'Uthibitishaji wa barua pepe umekamilika.',
                  ),
                ),
              if (!emailVerified) ...[
                FilledButton(
                  onPressed: emailLoading ? null : verifyEmailOtp,
                  child: Text(
                    emailLoading
                        ? tx('Checking...', 'Inakagua...')
                        : tx('Verify email', 'Thibitisha barua pepe'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          key: profilePhoneKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasPendingPhone
                    ? tx('Verify new phone', 'Thibitisha simu mpya')
                    : phoneVerified
                    ? tx('Phone verified', 'Simu imethibitishwa')
                    : '${tx('Verify phone with', 'Thibitisha simu kwa')} ${otpProviderLabel(otpProvider)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Field(
                controller: newPhone,
                label: tx('New phone number', 'Namba mpya ya simu'),
                icon: Icons.phone_android_outlined,
                keyboard: TextInputType.phone,
              ),
              FilledButton.icon(
                onPressed: phoneChangeLoading ? null : startPhoneChange,
                icon: const Icon(Icons.swap_calls_outlined),
                label: Text(
                  phoneChangeLoading
                      ? tx('Sending OTP...', 'Inatuma OTP...')
                      : tx(
                          'Change phone and send OTP',
                          'Badili simu na tuma OTP',
                        ),
                ),
              ),
              const SizedBox(height: 10),
              if (!phoneVerified || hasPendingPhone) ...[
                VerificationStatusLine(
                  sent: sent,
                  visibleCode: visiblePhoneCode,
                  destination: verificationPhone(),
                  pendingText: hasPendingPhone
                      ? tx(
                          'New phone is pending. Verify it before it replaces the current number.',
                          'Simu mpya inasubiri. Ithibitishe kabla haijachukua nafasi ya namba ya sasa.',
                        )
                      : tx(
                          'Phone is pending. Send an OTP to verify this account.',
                          'Simu haijathibitishwa. Tuma OTP kuthibitisha akaunti.',
                        ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: loading ? null : sendOtp,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(
                    sent
                        ? tx('OTP sent again', 'OTP imetumwa tena')
                        : tx('Send OTP', 'Tuma OTP'),
                  ),
                ),
                const SizedBox(height: 10),
                Field(
                  controller: code,
                  label: tx(
                    'Enter phone verification code',
                    'Weka kodi ya kuthibitisha simu',
                  ),
                  icon: Icons.password,
                  keyboard: TextInputType.number,
                ),
              ] else
                VerificationStatusLine(
                  sent: true,
                  visibleCode: null,
                  destination: widget.user['phone'] ?? '',
                  pendingText: tx(
                    'Phone verification is complete.',
                    'Uthibitishaji wa simu umekamilika.',
                  ),
                ),
              if (!phoneVerified || hasPendingPhone) ...[
                FilledButton(
                  onPressed: loading ? null : verifyOtp,
                  child: Text(
                    loading
                        ? tx('Checking...', 'Inakagua...')
                        : tx('Verify phone number', 'Thibitisha namba ya simu'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfacePanel(
          key: profileDeleteKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tx('Account deletion', 'Kufuta akaunti'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                tx(
                  'Delete this account and remove this device session.',
                  'Futa akaunti hii na ondoa kipindi cha kifaa hiki.',
                ),
                style: const TextStyle(color: kTextColor),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: accountDeleteLoading ? null : deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  accountDeleteLoading
                      ? tx('Deleting...', 'Inafuta...')
                      : tx('Delete account', 'Futa akaunti'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(tx('Sign out', 'Toka')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}
