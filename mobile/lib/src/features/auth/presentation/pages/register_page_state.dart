part of '../../../../../main.dart';

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController(text: 'Demo Buyer');
  final phone = TextEditingController(text: '255700000001');
  final nida = TextEditingController();
  final address = TextEditingController(text: 'Dar es Salaam');
  final email = TextEditingController();
  final password = TextEditingController(text: 'password');
  String role = 'buyer';
  bool termsAccepted = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    applyPendingSocialPayload();
  }

  void applyPendingSocialPayload() {
    final pendingPayload = widget.pendingSocialPayload;
    if (pendingPayload == null) return;

    final pendingRole = '${pendingPayload['role'] ?? ''}'.trim();
    if (pendingRole == 'buyer' ||
        pendingRole == 'seller' ||
        pendingRole == 'deliverer') {
      role = pendingRole;
    }

    final socialName = '${pendingPayload['full_name'] ?? ''}'.trim();
    if (socialName.isNotEmpty && !socialName.endsWith(' user')) {
      name.text = socialName;
    }

    final socialPhone = normalizePhoneInput('${pendingPayload['phone'] ?? ''}');
    if (socialPhone.isNotEmpty) {
      phone.text = socialPhone;
    }
  }

  Future<String?> fcmToken() async {
    return firebaseMessagingToken();
  }

  void completeSignIn(Map<String, dynamic> response) {
    final user = response['user'] as Map<String, dynamic>;
    final codes = response['verification_codes'];
    if (codes is Map<String, dynamic>) {
      user['_verification_codes'] = codes;
    }
    user['_open_phone_verification'] = true;
    widget.onSignedIn(response['token'] as String, user);
    if (mounted) Navigator.of(context).pop();
  }

  void requireRegistrationDetails({required bool includeEmailPassword}) {
    final missing = <String>[];
    if (role.trim().isEmpty) missing.add(tx('account type', 'aina ya akaunti'));
    if (name.text.trim().isEmpty) missing.add(tx('full name', 'jina kamili'));
    if (includeEmailPassword && email.text.trim().isEmpty) {
      missing.add(tx('email', 'barua pepe'));
    }
    if (phone.text.trim().isEmpty) missing.add(tx('phone', 'simu'));
    if (nida.text.trim().isEmpty) {
      missing.add(tx('NIDA number', 'namba ya NIDA'));
    }
    if (address.text.trim().isEmpty) missing.add(tx('address', 'anwani'));
    if (includeEmailPassword && password.text.isEmpty) {
      missing.add(tx('password', 'nenosiri'));
    }
    if (!termsAccepted) {
      missing.add(tx('terms and conditions', 'vigezo na masharti'));
    }
    if (missing.isNotEmpty) {
      throw Exception(
        '${tx('Complete these fields first:', 'Kamilisha taarifa hizi kwanza:')} ${missing.join(', ')}.',
      );
    }
    requireTwelveDigitPhone(phone.text);
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      requireRegistrationDetails(includeEmailPassword: true);
      final normalizedPhone = requireTwelveDigitPhone(phone.text);
      final response = await widget.client.post('/auth/register', {
        'role': role,
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': normalizedPhone,
        'nida_number': nida.text.trim(),
        'password': password.text,
        'address': address.text.trim(),
        'fcm_token': await fcmToken(),
        'terms_accepted': true,
      });
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> googleRegister() async {
    setState(() => loading = true);
    try {
      final auth = await googleBackendAuthPayload();
      final response = await socialRegister(
        credentials: {
          if (auth['firebase_id_token'] != null)
            'firebase_id_token': auth['firebase_id_token'],
          if (auth['google_access_token'] != null)
            'google_access_token': auth['google_access_token'],
        },
        fallbackName: auth['_display_name'] ?? 'Google user',
      );
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>> socialRegister({
    required Map<String, dynamic> credentials,
    required String fallbackName,
  }) async {
    requireRegistrationDetails(includeEmailPassword: false);
    final normalizedPhone = requireTwelveDigitPhone(phone.text);
    return widget.client.post('/auth/google', {
      ...credentials,
      'role': role,
      'full_name': name.text.trim().isEmpty ? fallbackName : name.text.trim(),
      'phone': normalizedPhone,
      'nida_number': nida.text.trim(),
      'address': address.text.trim(),
      'fcm_token': await fcmToken(),
      'terms_accepted': true,
    });
  }

  Future<void> pendingSocialRegister() async {
    final pendingPayload = widget.pendingSocialPayload;
    final providerName = widget.pendingSocialProviderName;
    if (pendingPayload == null || providerName == null) return;

    setState(() => loading = true);
    try {
      final response = await socialRegister(
        credentials: {
          if (pendingPayload['firebase_id_token'] != null)
            'firebase_id_token': pendingPayload['firebase_id_token'],
          if (pendingPayload['google_access_token'] != null)
            'google_access_token': pendingPayload['google_access_token'],
          if (pendingPayload['google_id_token'] != null)
            'google_id_token': pendingPayload['google_id_token'],
        },
        fallbackName: '$providerName user',
      );
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> appleRegister() async {
    setState(() => loading = true);
    try {
      final appleAuth = await signInWithAppleFirebase();
      final firebaseUser = appleAuth.credential.user;
      final token = await refreshedFirebaseIdToken(
        firebaseUser,
        feature: 'Apple registration',
      );
      final currentFirebaseUser =
          FirebaseAuth.instance.currentUser ?? firebaseUser;
      final response = await socialRegister(
        credentials: {'firebase_id_token': token},
        fallbackName:
            appleAuth.displayName ??
            currentFirebaseUser?.displayName ??
            'Apple user',
      );
      completeSignIn(response);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    nida.dispose();
    address.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingSocialProviderName = widget.pendingSocialProviderName;
    final pendingSocialPayload = widget.pendingSocialPayload;
    final hasPendingSocialLogin =
        pendingSocialPayload != null && pendingSocialProviderName != null;
    final pendingSocialEmail = '${pendingSocialPayload?['_email'] ?? ''}'
        .trim();
    final showApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return Scaffold(
      appBar: AppBar(title: Text(tx('Create account', 'Fungua akaunti'))),
      body: SafeArea(
        child: ResponsiveListView(
          maxWidth: kResponsiveFormMaxWidth,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            const RegisterVisualHeader(),
            const SizedBox(height: 10),
            SurfacePanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tx('Choose your account type', 'Chagua aina ya akaunti'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RoleSelector(
                    value: role,
                    onChanged: (value) => setState(() => role = value),
                  ),
                  const SizedBox(height: 10),
                  SectionTitle(
                    title: tx('Fast registration', 'Usajili wa haraka'),
                  ),
                  const SizedBox(height: 6),
                  if (hasPendingSocialLogin) ...[
                    Text(
                      tx(
                        pendingSocialEmail.isEmpty
                            ? 'No account exists for this $pendingSocialProviderName login. Complete your details below and we will create the account with the same login.'
                            : 'No account exists for $pendingSocialEmail. Complete your details below and we will create the account with your $pendingSocialProviderName login.',
                        pendingSocialEmail.isEmpty
                            ? 'Hakuna akaunti kwa uingiaji huu wa $pendingSocialProviderName. Kamilisha taarifa zako hapa chini na tutafungua akaunti kwa uingiaji huo huo.'
                            : 'Hakuna akaunti ya $pendingSocialEmail. Kamilisha taarifa zako hapa chini na tutafungua akaunti kwa uingiaji wako wa $pendingSocialProviderName.',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: kTextColor),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : googleRegister,
                      icon: const Icon(Icons.login),
                      label: Text(
                        tx('Register with Google', 'Jisajili na Google'),
                      ),
                      style: socialButtonStyle(context),
                    ),
                    if (showApple) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: loading ? null : appleRegister,
                        icon: const Icon(Icons.apple),
                        label: Text(
                          tx('Register with Apple', 'Jisajili na Apple'),
                        ),
                        style: socialButtonStyle(context),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SurfacePanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(title: tx('Your details', 'Taarifa zako')),
                  const SizedBox(height: 6),
                  Field(
                    controller: name,
                    label: tx('Full name', 'Jina kamili'),
                    icon: Icons.person_outline,
                  ),
                  if (!hasPendingSocialLogin)
                    Field(
                      controller: email,
                      label: tx('Email', 'Barua pepe'),
                      icon: Icons.alternate_email,
                      keyboard: TextInputType.emailAddress,
                    ),
                  Field(
                    controller: phone,
                    label: tx(
                      'Phone for OTP and payments',
                      'Simu ya OTP na malipo',
                    ),
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                  Field(
                    controller: nida,
                    label: tx('NIDA number', 'Namba ya NIDA'),
                    icon: Icons.badge_outlined,
                    keyboard: TextInputType.number,
                  ),
                  Field(
                    controller: address,
                    label: tx('Default address', 'Anwani ya msingi'),
                    icon: Icons.place_outlined,
                  ),
                  if (!hasPendingSocialLogin)
                    Field(
                      controller: password,
                      label: tx('Password', 'Nenosiri'),
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),
                  CheckboxListTile(
                    value: termsAccepted,
                    onChanged: loading
                        ? null
                        : (value) =>
                              setState(() => termsAccepted = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tx(
                        'I accept the Terms and Conditions',
                        'Ninakubali Vigezo na Masharti',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      tx(
                        'Required before creating a Discount Link account.',
                        'Inahitajika kabla ya kufungua akaunti ya Discount Link.',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: loading
                        ? null
                        : hasPendingSocialLogin
                        ? pendingSocialRegister
                        : register,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                      loading
                          ? tx('Registering...', 'Inasajili...')
                          : hasPendingSocialLogin
                          ? tx(
                              'Complete $pendingSocialProviderName registration',
                              'Kamilisha usajili wa $pendingSocialProviderName',
                            )
                          : tx('Register', 'Jisajili'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
