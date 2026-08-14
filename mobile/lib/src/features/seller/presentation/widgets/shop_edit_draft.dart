part of '../../../../../main.dart';

class _ShopEditDraft {
  _ShopEditDraft({
    required String name,
    required String address,
    required Set<String> categories,
    required this.openingTime,
    required this.closingTime,
  }) : name = TextEditingController(text: name),
       address = TextEditingController(text: address),
       categories = {...categories};

  final TextEditingController name;
  final TextEditingController address;
  final Set<String> categories;
  String openingTime;
  String closingTime;

  void dispose() {
    name.dispose();
    address.dispose();
  }
}
