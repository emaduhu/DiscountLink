part of '../../../../../main.dart';

class _ProductEditDraft {
  _ProductEditDraft(Map<String, dynamic> product)
    : name = TextEditingController(text: product['name'] ?? ''),
      description = TextEditingController(text: product['description'] ?? ''),
      price = TextEditingController(text: '${product['price'] ?? ''}'),
      discount = TextEditingController(
        text: '${product['discount_percent'] ?? '0'}',
      ),
      delivery = TextEditingController(
        text: '${product['delivery_price'] ?? ''}',
      ),
      stock = TextEditingController(text: '${product['stock'] ?? '0'}');

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController price;
  final TextEditingController discount;
  final TextEditingController delivery;
  final TextEditingController stock;

  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    discount.dispose();
    delivery.dispose();
    stock.dispose();
  }
}
