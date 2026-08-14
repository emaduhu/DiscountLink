part of '../../../../../main.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;

  @override
  State<CartPage> createState() => _CartPageState();
}
