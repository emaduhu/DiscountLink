part of '../../../../../main.dart';

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  bool codeSent = false;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> requestCode() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.post('/auth/password/forgot', {
        'email': email.text.trim(),
      });
      if (!mounted) return;
      setState(() => codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${r['message'] ?? 'Reset code sent.'}')),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    setState(() => loading = true);
    try {
      final r = await widget.client.post('/auth/password/reset', {
        'email': email.text.trim(),
        'code': code.text.trim(),
        'password': password.text,
        'password_confirmation': passwordConfirmation.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r['message'] ?? 'Password reset successful. You can now sign in.'}',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx('Reset password', 'Weka upya nenosiri'))),
    body: SafeArea(
      child: ResponsiveListView(
        maxWidth: kResponsiveFormMaxWidth,
        padding: const EdgeInsets.all(kDefaultPadding),
        children: [
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset_outlined,
                  color: kPrimaryColor,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  tx('Forgot password?', 'Umesahau nenosiri?'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your email to receive a reset code, then create a new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kTextColor),
                ),
                const SizedBox(height: 18),
                Field(
                  controller: email,
                  label: tx('Email', 'Barua pepe'),
                  icon: Icons.alternate_email,
                  keyboard: TextInputType.emailAddress,
                ),
                if (codeSent) ...[
                  Field(
                    controller: code,
                    label: tx('Reset code', 'Kodi ya kuweka upya'),
                    icon: Icons.pin_outlined,
                    keyboard: TextInputType.number,
                  ),
                  Field(
                    controller: password,
                    label: tx('New password', 'Nenosiri jipya'),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                  Field(
                    controller: passwordConfirmation,
                    label: tx('Confirm password', 'Thibitisha nenosiri'),
                    icon: Icons.lock_outline,
                    obscure: true,
                  ),
                ],
                FilledButton(
                  onPressed: loading
                      ? null
                      : codeSent
                      ? resetPassword
                      : requestCode,
                  child: Text(
                    loading
                        ? tx('Please wait...', 'Tafadhali subiri...')
                        : codeSent
                        ? tx('Reset password', 'Weka upya nenosiri')
                        : tx('Send reset code', 'Tuma kodi'),
                  ),
                ),
                if (codeSent)
                  TextButton(
                    onPressed: loading ? null : requestCode,
                    child: Text(tx('Resend code', 'Tuma tena kodi')),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
