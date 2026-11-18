import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/common/basewidgets/product_widget.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';

Product _product(List<Map<String, dynamic>> reviews) => Product.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Aspirin 500 mg',
      'unit_price': 10,
      'purchase_price': 6,
      'discount': 0,
      'reviews_count': reviews.length,
      'reviews': reviews,
    });

Future<void> _showCard(WidgetTester tester, Product product) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ProductWidget(productModel: product)))));
  // The picture of the card is fetched by the image cache, which starts a timer of its own; it is let run before the test ends.
  await tester.pump(const Duration(milliseconds: 50));
}

/// K-07: the rating on the card of a product in the seller's own list counts the reviews that were approved. The card added up every review the product came with, including the ones the shop has not
/// approved, stopped on a review without a rating, and showed a rating of a product that has no reviews as a division by nothing.
void main() {
  group('the card of a product in the list', () {
    testWidgets('shows the average of the approved reviews and leaves out the ones that are not approved', (WidgetTester tester) async {
      await _showCard(tester, _product(<Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'rating': 5, 'status': 1},
        <String, dynamic>{'id': 2, 'rating': 1, 'status': 0},
        <String, dynamic>{'id': 3, 'rating': 3, 'status': 1},
        <String, dynamic>{'id': 4, 'rating': 1, 'status': 0},
      ]));

      expect(find.text('4.0'), findsOneWidget, reason: '(5 + 3) / 2, not (5 + 1 + 3 + 1) / 4 = 2.5');
      expect(find.text('2.5'), findsNothing);
    });

    testWidgets('shows 0.0 for a product whose reviews are all waiting for approval, and for a product with none', (WidgetTester tester) async {
      await _showCard(tester, _product(<Map<String, dynamic>>[<String, dynamic>{'id': 1, 'rating': 5, 'status': 0}]));
      expect(find.text('0.0'), findsOneWidget);

      await _showCard(tester, _product(<Map<String, dynamic>>[]));
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('is drawn when a review has no rating, and does not count it', (WidgetTester tester) async {
      await _showCard(tester, _product(<Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'rating': null, 'status': 1},
        <String, dynamic>{'id': 2, 'rating': 4, 'status': 1},
        <String, dynamic>{'id': 3, 'rating': 5, 'status': 1},
      ]));

      expect(find.text('4.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
