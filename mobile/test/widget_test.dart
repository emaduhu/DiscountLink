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

  testWidgets('product carousel activates only the visible media tile', (
    tester,
  ) async {
    const firstImage = 'assets/images/product_popular_1.png';
    const secondImage = 'assets/images/product_headset.png';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ProductMediaCarousel(
                media: [
                  {'type': 'image', 'url': firstImage},
                  {'type': 'image', 'url': secondImage},
                ],
              ),
            ),
          ),
        ),
      ),
    );

    var activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], firstImage);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    activeTiles = tester
        .widgetList<ProductMediaTile>(find.byType(ProductMediaTile))
        .where((tile) => tile.active)
        .toList();
    expect(activeTiles, hasLength(1));
    expect(activeTiles.single.media['url'], secondImage);
  });
}
