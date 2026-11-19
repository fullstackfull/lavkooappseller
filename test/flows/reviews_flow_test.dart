import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/features/review/controllers/product_review_controller.dart';
import 'package:syriacosmeticsmanger/features/review/domain/repositories/product_review_repository.dart';
import 'package:syriacosmeticsmanger/features/review/domain/services/review_service.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';

const String _listPath = '/api/v3/seller/shop-product-reviews';
const String _statusPath = '/api/v3/seller/shop-product-reviews-status';
const String _replyPath = '/api/v3/seller/shop-product-reviews-reply';
const String _productReviewsPath = '/api/v3/seller/products/review-list/7';

const String _enNoInternet = 'No internet connection';
const String _enTimeout = 'Connection timed out. Please try again';
const String _enReplyAdded = 'Reply added successfully';
const String _enStatusUpdated = 'Review status updated successfully';

/// The reviews of the seller's products, the filter, the status switch and the reply, as the seller app runs them: the
/// real controller, service and repository over the app's own Dio client, with a scripted server instead of the network.
class _ReviewsFlow {
  _ReviewsFlow._(this.adapter, this.reviews);

  final ScriptedAdapter adapter;
  final ProductReviewController reviews;

  static Future<_ReviewsFlow> pump(WidgetTester tester, ScriptedAdapter adapter) async {
    final DioClient client = await FlowHarness.client(adapter);
    final ProductReviewController reviews = ProductReviewController(
      reviewServiceInterface: ReviewService(productReviewRepoInterface: ProductReviewRepository(dioClient: client)),
    );

    await FlowHarness.pump(tester, providers: [ChangeNotifierProvider<ProductReviewController>.value(value: reviews)]);
    addTearDown(reviews.dispose);

    return _ReviewsFlow._(adapter, reviews);
  }

  Future<void> loadList(WidgetTester tester) => FlowHarness.call(tester, () => reviews.getReviewList(Get.context!));

  Future<void> loadProductReviews(WidgetTester tester, {int offset = 1, bool reload = false}) =>
      FlowHarness.call(tester, () => reviews.getProductWiseReviewList(Get.context!, offset, 7, reload: reload));

  Future<void> reply(WidgetTester tester, {String text = 'Thank you for the kind words.', bool fromProduct = false}) =>
      FlowHarness.call(tester, () => reviews.sendReviewReply(Get.context!, 31, 7, text, fromProduct));

  Future<void> switchStatus(WidgetTester tester, {required int status, bool fromProduct = false}) =>
      FlowHarness.call(tester, () => reviews.reviewStatusOnOff(Get.context!, 31, status, 0, fromProduct: fromProduct));
}

ScriptedAnswer _listOf(List<Map<String, Object?>> reviews) => ScriptedAnswer.json(reviewPageJson(reviews));

void main() {
  group('the review list', () {
    testWidgets('is a GET of the seller\'s reviews, signed in, with nothing in the address and no body',
        (WidgetTester tester) async {
      final _ReviewsFlow flow =
          await _ReviewsFlow.pump(tester, ScriptedAdapter.always(_listOf(<Map<String, Object?>>[reviewJson()])));

      await flow.loadList(tester);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _listPath);
      expect(flow.adapter.only.rawQuery, isEmpty);
      expect(flow.adapter.only.body, isNull);
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    testWidgets('shows what each review says: who wrote it, for which product, how many stars, and our reply',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.always(_listOf(<Map<String, Object?>>[
          reviewJson(id: 32, rating: 5, comment: 'Perfect.', reply: 'Glad you like it.'),
          reviewJson(rating: 2, status: 0),
        ])),
      );

      expect(flow.reviews.reviewList, isEmpty);

      await flow.loadList(tester);

      expect(flow.reviews.reviewList.map((review) => review.id), <int?>[32, 31]);
      expect(flow.reviews.reviewList.first.rating, 5.0);
      expect(flow.reviews.reviewList.first.comment, 'Perfect.');
      expect(flow.reviews.reviewList.first.reply!.replyText, 'Glad you like it.');
      expect(flow.reviews.reviewList.first.product!.name, 'Rose Serum');
      expect(flow.reviews.reviewList.first.customer!.fName, 'Test');
      expect(flow.reviews.reviewList.last.reply, isNull, reason: 'a review nobody answered has no reply to show');
      expect(flow.reviews.reviewList.last.status, 0, reason: 'a hidden review reads as hidden');
      expect(flow.reviews.isLoading, isFalse);
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets('may be empty, which is an answer and not a failure', (WidgetTester tester) async {
      final _ReviewsFlow flow =
          await _ReviewsFlow.pump(tester, ScriptedAdapter.always(_listOf(<Map<String, Object?>>[])));

      await flow.loadList(tester);

      expect(flow.reviews.reviewList, isEmpty);
      expect(flow.reviews.isLoading, isFalse);
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets('that is refused is shown in the server\'s words, and keeps the reviews already on screen',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          permissionRefusal()
        ]),
      );

      await flow.loadList(tester);
      await flow.loadList(tester);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.reviews.reviewList.map((review) => review.id), <int?>[31]);
      expect(flow.reviews.isLoading, isFalse);
    });

    for (final MapEntry<String, (ScriptedAnswer, String)> failure in <String, (ScriptedAnswer, String)>{
      'no signal': (ScriptedAnswer.offline(), _enNoInternet),
      'a connection that never completes': (ScriptedAnswer.timeout(), _enTimeout),
    }.entries) {
      testWidgets('that fails in transport (${failure.key}) is shown, throws nothing, and can be asked again',
          (WidgetTester tester) async {
        final _ReviewsFlow flow = await _ReviewsFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            failure.value.$1,
            _listOf(<Map<String, Object?>>[reviewJson()])
          ]),
        );

        await flow.loadList(tester);

        expect(FlowHarness.shown(tester), <String>[failure.value.$2]);
        expect(flow.reviews.reviewList, isEmpty);
        expect(flow.reviews.isLoading, isFalse, reason: 'the screen is not left waiting');

        await FlowHarness.dismissToast(tester);
        await flow.loadList(tester);

        expect(flow.adapter.requests, hasLength(2));
        expect(flow.reviews.reviewList.single.id, 31);
      });
    }
  });

  group('the reviews of one product', () {
    testWidgets('are asked for by the product\'s id, ten at a time, from the page the screen is on',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<String, Object?>{
          ...reviewPageJson(<Map<String, Object?>>[reviewJson()]),
          'average_rating': '4.50',
          'group-wise-rating': <Object?>[
            <String, Object?>{'rating': 5, 'total': 1},
          ],
        })),
      );

      await flow.loadProductReviews(tester);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _productReviewsPath);
      expect(flow.adapter.only.query, <String, String>{'limit': '10', 'offset': '1'});
      FlowHarness.expectSignedIn(flow.adapter.only);
      expect(flow.reviews.productReviewModel!.averageRating, '4.50');
      expect(flow.reviews.productReviewModel!.groupWiseRating!.single.total, 1);
      expect(flow.reviews.productReviewList.single.id, 31);
      expect(flow.reviews.isLoading, isFalse);
    });

    testWidgets('add the next page to the first, and a first page starts the list again', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson(id: 33)]),
          _listOf(<Map<String, Object?>>[reviewJson(id: 32)]),
          _listOf(<Map<String, Object?>>[reviewJson(id: 34)]),
        ]),
      );

      await flow.loadProductReviews(tester);
      await flow.loadProductReviews(tester, offset: 2);

      expect(flow.adapter.requests.map((request) => request.query['offset']), <String?>['1', '2']);
      expect(flow.reviews.productReviewList.map((review) => review.id), <int?>[33, 32]);

      await flow.loadProductReviews(tester, reload: true);

      expect(flow.reviews.productReviewList.map((review) => review.id), <int?>[34]);
    });

    testWidgets('that are refused are shown in the server\'s words', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

      await flow.loadProductReviews(tester);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.reviews.productReviewList, isEmpty);
    });

    testWidgets('survive a transport failure and can be asked for again', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          _listOf(<Map<String, Object?>>[reviewJson()])
        ]),
      );

      await flow.loadProductReviews(tester);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(flow.reviews.productReviewList, isEmpty);

      await FlowHarness.dismissToast(tester);
      await flow.loadProductReviews(tester, reload: true);

      expect(flow.reviews.productReviewList.single.id, 31);
    });
  });

  group('filtering the reviews', () {
    // The screen offers three choices of status and the API reads two: "select status" asks for no status at all, and
    // "inactive" is the API's 0.
    const Map<int, String?> statusSentForChoice = <int, String?>{0: null, 1: '1', 2: '0'};

    for (final MapEntry<int, String?> choice in statusSentForChoice.entries) {
      testWidgets('with the status choice ${choice.key} asks for status ${choice.value ?? 'none'}',
          (WidgetTester tester) async {
        final _ReviewsFlow flow =
            await _ReviewsFlow.pump(tester, ScriptedAdapter.always(_listOf(<Map<String, Object?>>[])));
        flow.reviews.setReviewStatusIndex(choice.key);

        await FlowHarness.call(tester, () => flow.reviews.filterReviewList(Get.context!, 7, '55'));

        expect(flow.adapter.only.method, 'GET');
        expect(flow.adapter.only.path, _listPath);
        expect(flow.adapter.only.query['product_id'], '7');
        expect(flow.adapter.only.query['customer_id'], '55');
        expect(flow.adapter.only.query['status'], choice.value);
        expect(flow.adapter.only.query.keys, isNot(contains('from')));
        expect(flow.adapter.only.query.keys, isNot(contains('to')));
        FlowHarness.expectSignedIn(flow.adapter.only);
      });
    }

    testWidgets('leaves out the product and the customer the seller did not choose', (WidgetTester tester) async {
      final _ReviewsFlow flow =
          await _ReviewsFlow.pump(tester, ScriptedAdapter.always(_listOf(<Map<String, Object?>>[])));

      await FlowHarness.call(tester, () => flow.reviews.filterReviewList(Get.context!, 0, '0'));

      expect(flow.adapter.only.rawQuery, isEmpty);
    });

    testWidgets('replaces the list with what was found and closes the filter', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson(), reviewJson(id: 32)]),
          _listOf(<Map<String, Object?>>[reviewJson(id: 32, rating: 1)]),
        ]),
      );
      await flow.loadList(tester);

      await FlowHarness.call(tester, () => flow.reviews.filterReviewList(Get.context!, 7, '55'));

      expect(flow.reviews.reviewList.map((review) => review.id), <int?>[32]);
      expect(flow.reviews.reviewList.single.rating, 1.0);
      expect(FlowHarness.screenIsOpen(tester), isFalse, reason: 'the success handler closed the filter');
    });

    testWidgets('that is refused is shown in the server\'s words, keeps the list, and leaves the filter open',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          permissionRefusal()
        ]),
      );
      await flow.loadList(tester);

      await FlowHarness.call(tester, () => flow.reviews.filterReviewList(Get.context!, 7, '55'));

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.reviews.reviewList.map((review) => review.id), <int?>[31]);
      expect(FlowHarness.screenIsOpen(tester), isTrue, reason: 'the seller keeps the filter to change it');
      expect(flow.reviews.isLoading, isFalse);
    });

    testWidgets('survives a transport failure and leaves the filter open for another try', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(tester, ScriptedAdapter.always(ScriptedAnswer.offline()));

      await FlowHarness.call(tester, () => flow.reviews.filterReviewList(Get.context!, 7, '55'));

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.reviews.isLoading, isFalse);
    });

    testWidgets('by a search sends the words the seller typed', (WidgetTester tester) async {
      final _ReviewsFlow flow =
          await _ReviewsFlow.pump(tester, ScriptedAdapter.always(_listOf(<Map<String, Object?>>[reviewJson()])));

      await FlowHarness.call(tester, () => flow.reviews.searchReviewList(Get.context!, 'serum'));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _listPath);
      expect(flow.adapter.only.query, <String, String>{'search': 'serum'});
      expect(flow.reviews.reviewList.single.id, 31);
      expect(flow.reviews.isSearching, isFalse);
    });

    testWidgets('by a search that is refused is shown in the server\'s words and does not leave the search spinning',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

      await FlowHarness.call(tester, () => flow.reviews.searchReviewList(Get.context!, 'serum'));

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.reviews.isSearching, isFalse);
    });
  });

  group('switching a review on or off', () {
    testWidgets('is a GET of the review and the status it should have', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          ScriptedAnswer.json(<String, Object?>{'message': 'Status updated'}),
        ]),
      );
      await flow.loadList(tester);

      await flow.switchStatus(tester, status: 0);

      expect(flow.adapter.requests.last.method, 'GET');
      expect(flow.adapter.requests.last.path, _statusPath);
      expect(flow.adapter.requests.last.query, <String, String>{'id': '31', 'status': '0'});
      FlowHarness.expectSignedIn(flow.adapter.requests.last);
    });

    testWidgets('that the server accepted is told to the seller and shows on the review', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          ScriptedAnswer.json(<String, Object?>{'message': 'Status updated'}),
        ]),
      );
      await flow.loadList(tester);
      expect(flow.reviews.reviewList.single.status, 1);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>[_enStatusUpdated]);
      expect(flow.reviews.reviewList.single.status, 0);
    });

    testWidgets('that the server cannot do is shown in its words and leaves the review as it was',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          errorsRefusal('review', 'Review not found.', status: 404),
        ]),
      );
      await flow.loadList(tester);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>['Review not found.']);
      expect(flow.reviews.reviewList.single.status, 1);
    });

    testWidgets('survives a transport failure and leaves the review as it was', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          _listOf(<Map<String, Object?>>[reviewJson()]),
          ScriptedAnswer.timeout()
        ]),
      );
      await flow.loadList(tester);

      await flow.switchStatus(tester, status: 0);

      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.reviews.reviewList.single.status, 1);
    });
  });

  group('replying to a review', () {
    testWidgets('is a POST of the review and the words of the reply, signed in', (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.json(<String, Object?>{'message': 'Review reply successfully'}),
          _listOf(<Map<String, Object?>>[]),
        ]),
      );

      await flow.reply(tester, text: 'Thank you for the kind words.');

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _replyPath);
      expect(request.rawQuery, isEmpty);
      expect(request.fields, <String, Object?>{'review_id': 31, 'reply_text': 'Thank you for the kind words.'});
      FlowHarness.expectSignedIn(request);
    });

    testWidgets('that was accepted is told to the seller, closes the reply screen, and reads the reviews again',
        (WidgetTester tester) async {
      String? replyOnServer;
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'GET $_listPath': (_) => _listOf(<Map<String, Object?>>[reviewJson(reply: replyOnServer)]),
          'POST $_replyPath': (RecordedRequest request) {
            replyOnServer = request.fields['reply_text']! as String;
            return ScriptedAnswer.json(<String, Object?>{'message': 'Review reply successfully'});
          },
        }),
      );
      await flow.loadList(tester);
      expect(flow.reviews.reviewList.single.reply, isNull);

      await flow.reply(tester, text: 'Thank you for the kind words.');

      expect(FlowHarness.shown(tester), <String>[_enReplyAdded]);
      expect(FlowHarness.screenIsOpen(tester), isFalse, reason: 'the success handler closed the reply screen');
      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['GET $_listPath', 'POST $_replyPath', 'GET $_listPath'],
      );
      expect(flow.reviews.reviewList.single.reply!.replyText, 'Thank you for the kind words.');
      expect(flow.reviews.isLoading, isFalse);
    });

    testWidgets('from the reviews of one product reads that product\'s reviews again, not the whole list',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.routes(<String, ScriptedServer>{
          'POST $_replyPath': (_) => ScriptedAnswer.json(<String, Object?>{'message': 'Review reply successfully'}),
          'GET $_productReviewsPath': (_) =>
              _listOf(<Map<String, Object?>>[reviewJson(reply: 'Thank you for the kind words.')]),
        }),
      );

      await flow.reply(tester, text: 'Thank you for the kind words.', fromProduct: true);

      expect(
        flow.adapter.requests.map((request) => '${request.method} ${request.path}'),
        <String>['POST $_replyPath', 'GET $_productReviewsPath'],
      );
      expect(flow.adapter.requests.last.query, <String, String>{'limit': '10', 'offset': '1'});
      expect(flow.reviews.productReviewList.single.reply!.replyText, 'Thank you for the kind words.');
    });

    testWidgets('that the server refuses is shown in its words, leaves the reply screen open, and reads nothing again',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(tester, ScriptedAdapter.always(permissionRefusal()));

      await flow.reply(tester);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(FlowHarness.screenIsOpen(tester), isTrue, reason: 'the seller keeps what they wrote');
      expect(flow.adapter.requests, hasLength(1));
      expect(flow.reviews.isLoading, isFalse, reason: 'the send button is usable again');
    });

    testWidgets('survives a transport failure, leaves the screen open, and sends the same words again on retry',
        (WidgetTester tester) async {
      final _ReviewsFlow flow = await _ReviewsFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          ScriptedAnswer.json(<String, Object?>{'message': 'Review reply successfully'}),
          _listOf(<Map<String, Object?>>[reviewJson(reply: 'Thank you for the kind words.')]),
        ]),
      );

      await flow.reply(tester, text: 'Thank you for the kind words.');

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.reviews.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await flow.reply(tester, text: 'Thank you for the kind words.');

      expect(flow.adapter.requests[1].fields, flow.adapter.requests.first.fields);
      expect(FlowHarness.shown(tester), <String>[_enReplyAdded]);
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });
  });
}
