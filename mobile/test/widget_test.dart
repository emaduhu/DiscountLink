import 'package:flutter_test/flutter_test.dart';
import 'package:discountlink/main.dart';

void main() {
  testWidgets('renders Discount Link login', (tester) async {
    await tester.pumpWidget(const DiscountLinkApp());
    expect(find.text('Discount Link'), findsOneWidget);
  });
}
