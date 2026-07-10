import 'package:discount_link/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Discount Link login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          client: ApiClient('https://example.test'),
          onSignedIn: (_, _) {},
        ),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
