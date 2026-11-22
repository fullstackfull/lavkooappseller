import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/product_helper.dart';

Reviews _review({required int? status, required int? rating}) => Reviews(status: status, rating: rating);

/// K-07: the rating a product shows counts the reviews that were approved, on every screen that shows one. A review that a customer wrote and the shop has not approved is not shown to customers and must
/// not move the rating the seller sees. The POS product dialog and the product sheet of an order edit averaged every review the product came with, failed on a review without a rating and divided by the
/// number of reviews, which is zero for a product that has none.
void main() {
  group('the rating of a product', () {
    test('is the average of its approved reviews and leaves out the ones that are not approved', () {
      final List<Reviews> reviews = <Reviews>[
        _review(status: 1, rating: 5),
        _review(status: 0, rating: 1),
        _review(status: 1, rating: 3),
        _review(status: 0, rating: 1),
      ];

      expect(ProductHelper.getApprovedReviewAverage(reviews), 4.0);
    });

    test('is not moved by a review that has not been approved, however low or high it is', () {
      final List<Reviews> approved = <Reviews>[_review(status: 1, rating: 4)];

      for (final int rating in <int>[1, 2, 3, 4, 5]) {
        expect(ProductHelper.getApprovedReviewAverage(<Reviews>[...approved, _review(status: 0, rating: rating)]), 4.0, reason: 'unapproved $rating');
      }
    });

    test('is 0 when nothing was approved: no reviews, a missing list, only reviews that are not approved', () {
      expect(ProductHelper.getApprovedReviewAverage(null), 0);
      expect(ProductHelper.getApprovedReviewAverage(<Reviews>[]), 0);
      expect(ProductHelper.getApprovedReviewAverage(<Reviews>[_review(status: 0, rating: 5), _review(status: null, rating: 5)]), 0);
    });

    test('does not fail on a review that has no rating, and does not count it', () {
      final List<Reviews> reviews = <Reviews>[_review(status: 1, rating: null), _review(status: 1, rating: 4), _review(status: 1, rating: 5)];

      expect(ProductHelper.getApprovedReviewAverage(reviews), 4.5);
    });

    test('a status the server does not call approved is not approved', () {
      for (final int? status in <int?>[null, 0, 2, -1]) {
        expect(ProductHelper.getApprovedReviewAverage(<Reviews>[_review(status: status, rating: 5)]), 0, reason: 'status $status');
      }
    });

    test('reads the reviews of a product as the server sends them', () {
      final Product product = Product.fromJson(<String, dynamic>{
        'id': 1,
        'unit_price': 10,
        'purchase_price': 6,
        'discount': 0,
        'reviews': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'rating': 5, 'status': 1},
          <String, dynamic>{'id': 2, 'rating': 1, 'status': 0},
        ],
      });

      expect(ProductHelper.getApprovedReviewAverage(product.reviews), 5.0);
    });
  });

  group('the screens that show it', () {
    String code(String path) => File(path).readAsStringSync();

    test('the product dialog of the POS, the product sheet of an order edit and the card of a product take the rating from the one helper', () {
      final Map<String, String> reads = <String, String>{
        'lib/features/pos/widgets/product_variation_selection_dialog_widget.dart': 'ProductHelper.getApprovedReviewAverage(widget.product!.reviews)',
        'lib/features/order_edit/widgets/edit _product_bottomsheet.dart': 'ProductHelper.getApprovedReviewAverage(widget.product!.reviews)',
        'lib/common/basewidgets/product_widget.dart': 'ProductHelper.getApprovedReviewAverage(widget.productModel.reviews)',
      };

      for (final MapEntry<String, String> read in reads.entries) {
        expect(code(read.key), contains(read.value), reason: read.key);
      }
    });

    test('no file under lib adds up, folds or reduces the ratings of reviews by itself, whatever the variable is called', () {
      final List<String> found = <String>[];

      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final String withoutComments = entity.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
        for (final String statement in withoutComments.split(';')) {
          if (RegExp(r'\.rating\b').hasMatch(statement) && RegExp(r'\+=|\.fold\(|\.reduce\(').hasMatch(statement)) {
            found.add('${entity.path}: ${statement.trim().replaceAll(RegExp(r'\s+'), ' ')}');
          }
        }
      }

      expect(found, isEmpty, reason: 'an average of reviews is taken by ProductHelper.getApprovedReviewAverage, which counts the approved ones');
    });
  });
}
