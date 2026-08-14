part of '../../../../../main.dart';

class BuyerPage extends StatefulWidget {
  const BuyerPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<BuyerPage> createState() => _BuyerPageState();
}
