part of '../../../../../main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.client});
  final ApiClient client;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}
