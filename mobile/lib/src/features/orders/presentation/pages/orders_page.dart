part of '../../../../../main.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.client});
  final ApiClient client;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}
