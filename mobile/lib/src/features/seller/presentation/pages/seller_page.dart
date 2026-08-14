part of '../../../../../main.dart';

class SellerPage extends StatefulWidget {
  const SellerPage({super.key, required this.client, required this.user});
  final ApiClient client;
  final Map<String, dynamic> user;
  @override
  State<SellerPage> createState() => _SellerPageState();
}
