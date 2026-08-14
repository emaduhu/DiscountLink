part of '../../../../../main.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({
    super.key,
    required this.client,
    required this.user,
    required this.onUserChanged,
  });
  final ApiClient client;
  final Map<String, dynamic> user;
  final ValueChanged<Map<String, dynamic>> onUserChanged;
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}
