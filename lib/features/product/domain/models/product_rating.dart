import 'package:syriacosmeticsmanger/features/product/domain/models/product_model.dart';

/// The rating a product shows: the average of its approved reviews.
///
/// A review a customer wrote but the shop has not approved is not shown to customers, and it must not move the rating the seller sees on the product either. An earlier version averaged every review
/// the product came with, failed on a review without a rating and divided by the number of reviews, which is zero for a product that has none.
class ProductRating {
  const ProductRating._();

  /// The status of a review that has been approved (Review::scopeActive on the server).
  static const int approvedStatus = 1;

  static List<Reviews> approvedAmong(List<Reviews>? reviews) =>
      (reviews ?? <Reviews>[]).where((Reviews review) => review.status == approvedStatus && review.rating != null).toList();

  /// The average of the ratings of the approved reviews, 0 when there is none.
  static double averageOf(List<Reviews>? reviews) {
    final List<Reviews> approved = approvedAmong(reviews);
    if (approved.isEmpty) {
      return 0;
    }

    return approved.fold<int>(0, (int total, Reviews review) => total + review.rating!) / approved.length;
  }
}
