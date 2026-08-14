part of '../../../../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.client, required this.onSignedIn});
  final ApiClient client;
  final void Function(String token, Map<String, dynamic> user) onSignedIn;
  @override
  State<LoginPage> createState() => _LoginPageState();
}
