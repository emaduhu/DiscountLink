import 'package:flutter_test/flutter_test.dart';
import 'package:discountlink/main.dart';

void main() {
  testWidgets('renders DiscountLink login', (tester) async {
    await tester.pumpWidget(const DiscountLinkApp());
    expect(find.text('DiscountLink'), findsOneWidget);
  });
}
