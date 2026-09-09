part of '../../../../../main.dart';

class _LoginPageState extends State<LoginPage> {
  static const _socialRegistrationRequiredCode = 'social_registration_required';
  static const _socialTermsSignInMessage =
      'accept the Terms and Conditions before signing in';
  static const _socialTermsCreateMessage =
      'accept the Terms and Conditions before creating an account';
  static const _socialRegistrationRequiredMessage =
      'Complete registration with your name, phone, NIDA number, address, and password before using social sign-in';

  final email = TextEditingController();
  final password = TextEditingController();
  String role = 'buyer';
  bool loading = false;
  bool biometricAvailable = false;
  bool biometricSaved = false;
  bool passwordVisible = false;
  String? biometricAccountLabel;
  String biometricMethodLabel = 'biometrics';

  @override
  void initState() {
    super.initState();
    loadBiometricState();
  }

  Future<void> loadBiometricState() async {
    final available = await biometricAuth.canUseBiometrics();
    final saved = await biometricAuth.hasSavedLogin();
    final label = await biometricAuth.savedAccountLabel();
    final methodLabel = await biometricAuth.methodLabel();
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricSaved = saved;
      biometricAccountLabel = label;
      biometricMethodLabel = methodLabel;
    });
  }

  Future<String?> fcmToken() async {
    return firebaseMessagingToken();
  }

  Future<void> googleSignIn() async {
    setState(() => loading = true);
    try {
      final auth = await googleBackendAuthPayload();
      final socialPhone = normalizePhoneInput('${auth['_phone'] ?? ''}');
      final payload = <String, dynamic>{
        if (auth['firebase_id_token'] != null)
          'firebase_id_token': auth['firebase_id_token'],
        if (auth['google_access_token'] != null)
          'google_access_token': auth['google_access_token'],
        'role': role,
        'full_name': auth['_display_name'] ?? 'Google user',
        'phone': socialPhone.isEmpty
            ? ''
            : requireTwelveDigitPhone(socialPhone),
        'address': '',
        'fcm_token': await fcmToken(),
      };
      final response = await postSocialLogin(payload, providerName: 'Google');
      if (response == null) return;
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>?> postSocialLogin(
    Map<String, dynamic> payload, {
    required String providerName,
  }) async {
    try {
      return await widget.client.post('/auth/google', payload);
    } catch (error) {
      final message = error.toString();
      final registrationRequired =
          error is ApiException &&
          error.code == _socialRegistrationRequiredCode;
      if (registrationRequired ||
          message.contains(_socialRegistrationRequiredMessage)) {
        await openRegisterPage(
          pendingSocialProviderName: providerName,
          pendingSocialPayload: payload,
        );
        return null;
      }
      if (!message.contains(_socialTermsSignInMessage) &&
          !message.contains(_socialTermsCreateMessage)) {
        rethrow;
      }
      final accepted = await showSocialTermsDialog();
      if (!accepted) return null;
      return widget.client.post('/auth/google', {
        ...payload,
        'terms_accepted': true,
      });
    }
  }

  Future<bool> showSocialTermsDialog() async {
    var accepted = false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(tx('Terms and Conditions', 'Vigezo na Masharti')),
              content: CheckboxListTile(
                value: accepted,
                onChanged: (value) =>
                    setDialogState(() => accepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tx(
                    'I accept the Terms and Conditions',
                    'Ninakubali Vigezo na Masharti',
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(tx('Cancel', 'Ghairi')),
                ),
                FilledButton(
                  onPressed: accepted
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: Text(tx('Accept and sign in', 'Kubali na uingie')),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> appleSignIn() async {
    setState(() => loading = true);
    try {
      final appleAuth = await signInWithAppleFirebase();
      final firebaseUser = appleAuth.credential.user;
      final token = await refreshedFirebaseIdToken(
        firebaseUser,
        feature: 'Apple sign-in',
      );
      final currentFirebaseUser =
          FirebaseAuth.instance.currentUser ?? firebaseUser;
      final socialPhone = normalizePhoneInput(
        currentFirebaseUser?.phoneNumber ?? '',
      );
      final response = await postSocialLogin({
        'firebase_id_token': token,
        '_email': appleAuth.email ?? currentFirebaseUser?.email,
        'role': role,
        'full_name':
            appleAuth.displayName ??
            currentFirebaseUser?.displayName ??
            'Apple user',
        'phone': socialPhone.isEmpty
            ? ''
            : requireTwelveDigitPhone(socialPhone),
        'address': '',
        'fcm_token': await fcmToken(),
      }, providerName: 'Apple');
      if (response == null) return;
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openRegisterPage({
    String? pendingSocialProviderName,
    Map<String, dynamic>? pendingSocialPayload,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterPage(
          client: widget.client,
          onSignedIn: widget.onSignedIn,
          pendingSocialProviderName: pendingSocialProviderName,
          pendingSocialPayload: pendingSocialPayload,
        ),
      ),
    );
  }

  Future<void> openForgotPasswordPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(client: widget.client),
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> passwordLogin() async {
    setState(() => loading = true);
    try {
      final response = await widget.client.post('/auth/login', {
        'identifier': normalizeLoginIdentifier(email.text),
        'password': password.text,
        'fcm_token': await fcmToken(),
      });
      widget.onSignedIn(
        response['token'] as String,
        response['user'] as Map<String, dynamic>,
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> biometricLogin() async {
    setState(() => loading = true);
    try {
      final token = await biometricAuth.unlockToken();
      if (token == null || token.isEmpty) {
        throw Exception('Biometric unlock was cancelled.');
      }
      widget.client.token = token;
      final response = await widget.client.get('/me');
      widget.onSignedIn(token, response['user'] as Map<String, dynamic>);
    } catch (error) {
      widget.client.token = null;
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final minContentHeight = constraints.maxHeight > kDefaultPadding * 2
                ? constraints.maxHeight - kDefaultPadding * 2
                : 0.0;
            var contentWidth = constraints.maxWidth > 32
                ? constraints.maxWidth - 32
                : constraints.maxWidth;
            if (constraints.maxWidth >= kTabletBreakpoint &&
                contentWidth > kResponsiveFormMaxWidth) {
              contentWidth = kResponsiveFormMaxWidth;
            }

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(kDefaultPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: compact ? 4 : 10),
                        Image.asset(
                          'assets/images/welcome_image.png',
                          height: compact ? 112 : 145,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: appTitleColor(context),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in with Google, or use email/phone and password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: appMutedTextColor(context)),
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        SurfacePanel(
                          padding: EdgeInsets.all(compact ? 10 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RoleSelector(
                                value: role,
                                onChanged: (value) =>
                                    setState(() => role = value),
                              ),
                              const SizedBox(height: 12),
                              Field(
                                controller: email,
                                label: tx(
                                  'Email or phone',
                                  'Barua pepe au simu',
                                ),
                                icon: Icons.alternate_email,
                                keyboard: TextInputType.text,
                              ),
                              Field(
                                controller: password,
                                label: tx('Password', 'Nenosiri'),
                                icon: Icons.lock_outline,
                                obscure: !passwordVisible,
                                suffixIcon: IconButton(
                                  tooltip: passwordVisible
                                      ? tx('Hide password', 'Ficha nenosiri')
                                      : tx('Show password', 'Onyesha nenosiri'),
                                  onPressed: () => setState(
                                    () => passwordVisible = !passwordVisible,
                                  ),
                                  icon: Icon(
                                    passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: loading
                                      ? null
                                      : openForgotPasswordPage,
                                  child: Text(
                                    tx(
                                      'Forgot password?',
                                      'Umesahau nenosiri?',
                                    ),
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: loading ? null : passwordLogin,
                                child: Text(
                                  loading
                                      ? tx('Signing in...', 'Inaingia...')
                                      : tx('Login', 'Ingia'),
                                ),
                              ),
                              if (biometricAvailable && biometricSaved) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: loading ? null : biometricLogin,
                                  icon: Icon(
                                    biometricMethodLabel == 'Face ID'
                                        ? Icons.face
                                        : Icons.fingerprint,
                                  ),
                                  label: Text(
                                    biometricAccountLabel == null ||
                                            biometricAccountLabel!.isEmpty
                                        ? tx(
                                            'Unlock with $biometricMethodLabel',
                                            'Fungua kwa $biometricMethodLabel',
                                          )
                                        : tx(
                                            'Unlock ${biometricAccountLabel!} with $biometricMethodLabel',
                                            'Fungua ${biometricAccountLabel!} kwa $biometricMethodLabel',
                                          ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: appMutedTextColor(context),
                                          ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: loading ? null : googleSignIn,
                                icon: const Icon(Icons.login),
                                label: Text(
                                  tx(
                                    'Continue with Google',
                                    'Endelea na Google',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  foregroundColor: appForegroundColor(context),
                                  side: BorderSide(
                                    color: appBorderColor(context),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              if (!kIsWeb &&
                                  (defaultTargetPlatform ==
                                          TargetPlatform.iOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS)) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: loading ? null : appleSignIn,
                                  icon: const Icon(Icons.apple),
                                  label: Text(
                                    tx(
                                      'Continue with Apple',
                                      'Endelea na Apple',
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    foregroundColor: appForegroundColor(
                                      context,
                                    ),
                                    side: BorderSide(
                                      color: appBorderColor(context),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: loading ? null : openRegisterPage,
                                child: Text(
                                  tx(
                                    'No account? Register',
                                    'Huna akaunti? Jisajili',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
