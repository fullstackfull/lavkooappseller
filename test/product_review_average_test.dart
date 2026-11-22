import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';
import 'package:syriacosmeticsmanger/helper/product_helper.dart';

/// A review as the seller API serialises it inside a product's `reviews` array.
///
/// The array also holds reviews a customer has written but nobody has approved
/// yet (`status` 0). The rating on the order edit sheet used to average the whole
/// array, so a single unapproved 1-star review pulled a product with one 5-star
/// review down to 3.0.
Reviews _review({required int rating, required int status}) {
  return Reviews.fromJson(<String, dynamic>{
    'id': 1,
    'product_id': 9,
    'customer_id': 3,
    'comment': 'Arrived on time',
    'rating': rating,
    'status': status,
    'created_at': '2026-11-10T08:00:00.000000Z',
    'updated_at': '2026-11-10T08:00:00.000000Z',
  });
}

void main() {
  group('rating on the order edit sheet', () {
    test('an unapproved review does not move the rating', () {
      final List<Reviews> reviews = <Reviews>[
        _review(rating: 5, status: 1),
        _review(rating: 1, status: 0),
      ];

      expect(ProductHelper.getApprovedReviewAverage(reviews), 5);
    });

    test('approved reviews are averaged', () {
      final List<Reviews> reviews = <Reviews>[
        _review(rating: 5, status: 1),
        _review(rating: 4, status: 1),
        _review(rating: 1, status: 0),
      ];

      expect(ProductHelper.getApprovedReviewAverage(reviews), 4.5);
    });

    test('a product with no reviews, or none approved, has no rating, and the sheet does not crash', () {
      expect(ProductHelper.getApprovedReviewAverage(null), 0);
      expect(ProductHelper.getApprovedReviewAverage(<Reviews>[]), 0);
      expect(ProductHelper.getApprovedReviewAverage(<Reviews>[_review(rating: 2, status: 0)]), 0);
    });

    test('a review that carries no status or no rating is left out instead of throwing', () {
      final List<Reviews> reviews = <Reviews>[
        _review(rating: 4, status: 1),
        Reviews(rating: 1),
        Reviews(status: 1),
      ];

      expect(ProductHelper.getApprovedReviewAverage(reviews), 4);
    });

    test('the status and rating survive the product JSON the sheet is built from', () {
      final Product product = Product.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Hand cream',
        'unit_price': 10,
        'purchase_price': 6,
        'discount': 0,
        'reviews': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'product_id': 9, 'rating': 5, 'status': 1},
          <String, dynamic>{'id': 2, 'product_id': 9, 'rating': 1, 'status': 0},
        ],
      });

      expect(product.reviews?.map((Reviews review) => review.status), <int?>[1, 0]);
      expect(ProductHelper.getApprovedReviewAverage(product.reviews), 5);
    });
  });
}
