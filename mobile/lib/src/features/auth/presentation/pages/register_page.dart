part of '../../../../../main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.client,
    required this.onSignedIn,
    this.pendingSocialProviderName,
    this.pendingSocialPayload,
  });
  final ApiClient client;
  final void Function(String token, Map<String, dynamic> user) onSignedIn;
  final String? pendingSocialProviderName;
  final Map<String, dynamic>? pendingSocialPayload;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
