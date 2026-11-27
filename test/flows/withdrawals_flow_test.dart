import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syriacosmeticsmanger/core/app_context.dart';
import 'package:syriacosmeticsmanger/data/datasource/remote/dio/dio_client.dart';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';
import 'package:syriacosmeticsmanger/data/model/response/response_model.dart';
import 'package:syriacosmeticsmanger/features/auth/controllers/auth_controller.dart';
import 'package:syriacosmeticsmanger/features/profile/controllers/profile_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/controllers/seller_center_controller.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/repositories/seller_center_repository.dart';
import 'package:syriacosmeticsmanger/features/seller_center/domain/services/seller_center_service.dart';
import 'package:syriacosmeticsmanger/features/shop/controllers/shop_controller.dart';
import 'package:syriacosmeticsmanger/features/transaction/controllers/transaction_controller.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:syriacosmeticsmanger/features/transaction/domain/services/transaction_service.dart';
import 'package:syriacosmeticsmanger/features/wallet/controllers/wallet_controller.dart';
import 'package:syriacosmeticsmanger/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:syriacosmeticsmanger/features/wallet/domain/services/wallet_service.dart';

import 'support/fixtures.dart';
import 'support/flow_harness.dart';
import 'support/scripted_adapter.dart';
import 'support/unused_services.dart';

const String _methodsPath = '/api/v3/seller/withdraw-method-list';
const String _withdrawPath = '/api/v3/seller/balance-withdraw';
const String _withdrawUpdatePath = '/api/v3/seller/balance-withdraw-update';
const String _closePath = '/api/v3/seller/close-withdraw-request';
const String _transactionsPath = '/api/v3/seller/transactions';
const String _payoutsPath = '/api/v3/seller/seller-center/payouts';
const String _cancelPayoutPath =
    '/api/v3/seller/seller-center/payouts/5/cancel';
const String _overviewPath = '/api/v3/seller/seller-center/overview';

const String _enNoInternet = 'No internet connection';
const String _enTimeout = 'Connection timed out. Please try again';
const String _enWithdrawSent = 'Withdraw request sent successfully';
const String _enKycRequired =
    'Verification is required before you can request a payout';
const String _invalidWithdrawText = 'Invalid withdraw request.';
const String _aboveWithdrawableText =
    'The amount is above what you can withdraw.';

class _RecordingProfileController extends ProfileController {
  _RecordingProfileController()
      : super(profileServiceInterface: UnusedProfileService());

  int sellerInfoReads = 0;
  final List<String> balancesGivenBack = <String>[];

  @override
  Future<ResponseModel> getSellerInfo() async {
    sellerInfoReads++;
    return ResponseModel(true, 'recorded');
  }

  @override
  void updateWalletAmount(String balance) => balancesGivenBack.add(balance);
}

class _RecordingShopController extends ShopController {
  _RecordingShopController() : super(shopServiceInterface: UnusedShopService());

  int shopReads = 0;

  @override
  Future<ResponseModel> getShopInfo() async {
    shopReads++;
    return ResponseModel(true, 'recorded');
  }
}

/// The withdrawals of the seller app: the wallet's request to the marketplace's own withdrawal method, the list of what
/// was asked for, and the payout requests of the ledger. The real controllers, services and repositories over the app's
/// own Dio client, with a scripted server instead of the network.
class _WithdrawFlow {
  _WithdrawFlow._(this.adapter, this.wallet, this.transactions, this.payouts,
      this.profile, this.shop, this.auth, this.routes);

  final ScriptedAdapter adapter;
  final WalletController wallet;
  final TransactionController transactions;
  final SellerCenterController payouts;
  final _RecordingProfileController profile;
  final _RecordingShopController shop;
  final RecordingAuthController auth;
  final RouteLog routes;

  static Future<_WithdrawFlow> pump(
      WidgetTester tester, ScriptedAdapter adapter) async {
    final DioClient client = await FlowHarness.client(adapter);
    final WalletController wallet = WalletController(
      walletServiceInterface: WalletService(
          walletRepoInterface: WalletRepository(dioClient: client)),
    );
    final TransactionController transactions = TransactionController(
      transactionServiceInterface: TransactionService(
          transactionRepoInterface: TransactionRepository(dioClient: client)),
    );
    final SellerCenterController payouts = SellerCenterController(
      sellerCenterServiceInterface: SellerCenterService(
          sellerCenterRepoInterface: SellerCenterRepository(dioClient: client)),
    );
    final _RecordingProfileController profile = _RecordingProfileController();
    final _RecordingShopController shop = _RecordingShopController();
    final RecordingAuthController auth = RecordingAuthController();
    final RouteLog routes = RouteLog();

    await FlowHarness.pump(tester, observers: <NavigatorObserver>[
      routes
    ], providers: [
      ChangeNotifierProvider<WalletController>.value(value: wallet),
      ChangeNotifierProvider<TransactionController>.value(value: transactions),
      ChangeNotifierProvider<SellerCenterController>.value(value: payouts),
      ChangeNotifierProvider<ProfileController>.value(value: profile),
      ChangeNotifierProvider<ShopController>.value(value: shop),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ]);

    addTearDown(wallet.dispose);
    addTearDown(transactions.dispose);
    addTearDown(payouts.dispose);
    addTearDown(auth.dispose);

    return _WithdrawFlow._(
        adapter, wallet, transactions, payouts, profile, shop, auth, routes);
  }

  /// The seller opens the withdraw sheet: the marketplace's methods are read, the first is chosen, and the two fields it
  /// asks for are typed.
  Future<void> fillTheSheet(WidgetTester tester,
      {String account = '9876543210', String holder = 'Test Holder'}) async {
    await FlowHarness.call(
        tester, () => wallet.getWithdrawMethods(Get.context!));
    wallet.setMethodTypeIndex(wallet.methodsIds.first);
    wallet.setTitle(0, account);
    wallet.setTitle(1, holder);
    adapter.requests.clear();
  }

  Future<void> withdraw(WidgetTester tester, {String amount = '150.5'}) =>
      FlowHarness.call(
          tester, () => wallet.updateBalance(amount, Get.context!));
}

/// A server for the wallet: the methods it offers, the list the wallet reads again after a request, and the answer to
/// each request made, in turn.
ScriptedAdapter _walletServer(List<ScriptedAnswer> answers) {
  int next = 0;
  return ScriptedAdapter((RecordedRequest request) {
    if (request.path == _methodsPath) {
      return ScriptedAnswer.json(<Object?>[withdrawMethodJson()]);
    }
    if (request.path == _transactionsPath) {
      return ScriptedAnswer.json(<Object?>[withdrawalJson()]);
    }
    return answers[next++];
  });
}

ScriptedAnswer get _withdrawAccepted =>
    ScriptedAnswer.json('Withdraw request sent successfully!');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The wallet shows a refusal as a native toast, which a test has no phone to show: what the app asked the plugin to
  // show is what is read.
  final List<String> toasts = <String>[];
  const MethodChannel toastChannel =
      MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, (MethodCall call) async {
      if (call.method == 'showToast') {
        toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(toastChannel, null);
  });

  group('the wallet\'s withdrawal request', () {
    testWidgets(
        'reads the methods the marketplace offers with a GET, and the sheet asks for the fields of the one chosen',
        (WidgetTester tester) async {
      final _WithdrawFlow flow =
          await _WithdrawFlow.pump(tester, _walletServer(<ScriptedAnswer>[]));

      await FlowHarness.call(
          tester, () => flow.wallet.getWithdrawMethods(Get.context!));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _methodsPath);
      FlowHarness.expectSignedIn(flow.adapter.only);
      expect(flow.wallet.methodList.single.methodName, 'Bank transfer');
      flow.wallet.setMethodTypeIndex(flow.wallet.methodsIds.first);
      expect(flow.wallet.keyList, <String?>['account_number', 'holder_name']);
      expect(flow.wallet.inputFieldControllerList, hasLength(2));
    });

    testWidgets(
        'is a POST of what the method asks for, the amount and the method\'s id, all as text, signed in',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, _walletServer(<ScriptedAnswer>[_withdrawAccepted]));
      await flow.fillTheSheet(tester);

      await flow.withdraw(tester, amount: '150.5');

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _withdrawPath);
      expect(request.rawQuery, isEmpty);
      expect(request.fields, <String, Object?>{
        'account_number': '9876543210',
        'holder_name': 'Test Holder',
        'amount': '150.5',
        'withdraw_method_id': '2',
      });
      FlowHarness.expectSignedIn(request);
    });

    testWidgets(
        'that was accepted is told to the seller, closes the sheet, and refreshes the list and the balance',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, _walletServer(<ScriptedAnswer>[_withdrawAccepted]));
      await flow.fillTheSheet(tester);

      await flow.withdraw(tester);

      expect(FlowHarness.shown(tester), <String>[_enWithdrawSent]);
      expect(FlowHarness.screenIsOpen(tester), isFalse,
          reason: 'the success handler closed the sheet');
      expect(
        flow.adapter.requests
            .map((request) => '${request.method} ${request.path}'),
        <String>['POST $_withdrawPath', 'GET $_transactionsPath'],
        reason: 'the request must show in the list the seller reads',
      );
      expect(flow.profile.sellerInfoReads, 1,
          reason: 'the balance the seller sees is read again');
      expect(flow.transactions.transactionList!.single.amount, 150.5);
      expect(flow.wallet.isLoading, isFalse);
      expect(flow.wallet.inputValueList, isEmpty,
          reason: 'the next request starts from empty fields');
      expect(toasts, isEmpty);
    });

    testWidgets(
        'that the server refuses is shown in its words, leaves the sheet open, and refreshes nothing',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          _walletServer(
              <ScriptedAnswer>[messageRefusal(_invalidWithdrawText)]));
      await flow.fillTheSheet(tester);

      await flow.withdraw(tester);

      expect(toasts, <String>[_invalidWithdrawText]);
      expect(FlowHarness.screenIsOpen(tester), isTrue,
          reason: 'the seller keeps what they typed');
      expect(flow.adapter.requests, hasLength(1));
      expect(flow.profile.sellerInfoReads, 0);
      expect(flow.wallet.isLoading, isFalse,
          reason: 'the button the seller pressed is usable again');
    });

    for (final MapEntry<String, ScriptedAnswer Function()> failure
        in <String, ScriptedAnswer Function()>{
      'no signal': ScriptedAnswer.offline,
      'a connection that never completes': ScriptedAnswer.timeout,
    }.entries) {
      testWidgets(
          'that fails in transport (${failure.key}) is shown, throws nothing, and leaves the sheet usable',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
            tester, _walletServer(<ScriptedAnswer>[failure.value()]));
        await flow.fillTheSheet(tester);

        await flow.withdraw(tester);

        expect(toasts, hasLength(1),
            reason: 'the seller is told something went wrong');
        expect(toasts.single, isNotEmpty);
        expect(FlowHarness.screenIsOpen(tester), isTrue);
        expect(flow.wallet.isLoading, isFalse);
        expect(flow.profile.sellerInfoReads, 0);
      });
    }

    // DEFECT K-16.4-D2, written down as the app behaves today rather than as it should. `updateBalance` shows the error
    // handler's key as it came, because it calls showToast with `apiResponse.error.toString()` instead of going through
    // ApiChecker, which is where every other screen gets its words. The payout screen on the same failure shows "No
    // internet connection", a few hundred lines below in this file, so the contrast is held by a passing test either
    // way. This is the transport half only: the same line throws outright on a refusal whose status the handler does
    // not name (D7 below), and never reaches ApiChecker on a 401 (D12 below).
    testWidgets(
        'that fails in transport shows the seller the error handler\'s key, which is a defect',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, _walletServer(<ScriptedAnswer>[ScriptedAnswer.offline()]));
      await flow.fillTheSheet(tester);

      await flow.withdraw(tester);

      expect(toasts, <String>['no_internet_connection'],
          reason:
              'what the seller reads today. It should be ["$_enNoInternet"], as the payout screen shows it');
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.wallet.isLoading, isFalse);
    });

    testWidgets(
        'sent again after a transport failure is the same request, and is accepted',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          _walletServer(
              <ScriptedAnswer>[ScriptedAnswer.offline(), _withdrawAccepted]));
      await flow.fillTheSheet(tester);

      await flow.withdraw(tester);
      await flow.withdraw(tester);

      expect(
          flow.adapter.requests.first.fields, flow.adapter.requests[1].fields);
      expect(FlowHarness.shown(tester), <String>[_enWithdrawSent]);
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });

    // DEFECT K-16.4-D3, written down as the app behaves today rather than as it should, and worse than stale values alone.
    // `updateBalance` appends each field's text to `inputValueList` without emptying it first, and only empties it after a
    // request the server accepted. So a refusal leaves the typed values in the list, the next attempt appends the corrected
    // ones behind them, and the request is built by walking the two-key list against a four-value list: the seller who
    // corrects their account number sends the number they had before, and the list grows by two with every refusal.
    testWidgets(
        'sent again with a corrected field carries the old value, which is a defect',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        _walletServer(<ScriptedAnswer>[
          messageRefusal(_invalidWithdrawText),
          _withdrawAccepted
        ]),
      );
      await flow.fillTheSheet(tester, account: '0000000000');
      await flow.withdraw(tester);

      expect(flow.wallet.inputValueList, <String>['0000000000', 'Test Holder'],
          reason:
              'the refused values are left in the list, where the next request will read them first');

      flow.wallet.setTitle(0, '9876543210');
      await flow.withdraw(tester);

      expect(flow.adapter.requests[1].fields['account_number'], '0000000000',
          reason:
              'what the seller sends today. It should be "9876543210", the number now in the field');
    });

    // DEFECT K-16.4-D7, written down as the app behaves today rather than as it should, and the worst of the set
    // because it is on the path money leaves the marketplace by. `updateBalance` asks `apiResponse.error.isNotEmpty`,
    // which only holds for the String the error handler answers for a status it names. For every other status the
    // handler answers the ErrorResponse object itself (D5), which has no `isNotEmpty`, so the line throws before any
    // toast is shown. 422 is the status the seller API documents for an amount above what may be withdrawn, so the one
    // refusal a seller is most likely to meet is the one that crashes.
    testWidgets(
        'that the server refuses with a 422 throws, tells the seller nothing and leaves the button loading, '
        'which is a defect', (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        _walletServer(<ScriptedAnswer>[
          errorsRefusal('amount', _aboveWithdrawableText, status: 422)
        ]),
      );
      await flow.fillTheSheet(tester);

      final Object? thrown = await FlowHarness.callThatThrows(
          tester, () => flow.wallet.updateBalance('9999', Get.context!));

      expect(thrown, isA<NoSuchMethodError>(),
          reason:
              'what happens today: wallet_controller.dart reads isNotEmpty off an ErrorResponse. '
              'It should be null, with the server\'s words shown');
      expect(toasts, isEmpty,
          reason:
              'what the seller reads today. It should be ["$_aboveWithdrawableText"]');
      expect(FlowHarness.shown(tester), isEmpty);
      expect(flow.wallet.isLoading, isTrue,
          reason:
              'the Request button is left spinning, because the throw skipped every _isLoading = false below it. '
              'It should be false');
      expect(FlowHarness.screenIsOpen(tester), isTrue);
      expect(flow.profile.sellerInfoReads, 0);
    });

    // DEFECT K-16.4-D12, the session half of D2. Because the wallet answers a refusal itself instead of handing it to
    // ApiChecker, a 401 never reaches the one place that signs a seller out: the seller reads the error handler's key
    // and is left on the sheet holding a token the API will refuse again. The order list, a few hundred lines away in
    // orders_flow_test.dart, signs out on the same answer, so the contrast is held by passing tests either way.
    testWidgets(
        'that the API refuses because the session expired leaves the seller signed in, which is a defect',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, _walletServer(<ScriptedAnswer>[expiredSession]));
      await flow.fillTheSheet(tester);
      final int openedBefore = flow.routes.pushed.length;

      await flow.withdraw(tester);

      expect(toasts, <String>['unauthorized'],
          reason:
              'what the seller reads today: the error handler\'s key, untranslated. '
              'They should be signed out, as the order list signs them out on the same answer');
      expect(flow.auth.sessionsWiped, 0,
          reason: 'what the device still holds today. It should be 1');
      expect(flow.auth.isUnAuthorize, isFalse);
      expect(flow.routes.pushed.length, openedBefore,
          reason: 'no sign-in screen was opened. One should have been');
      expect(FlowHarness.screenIsOpen(tester), isTrue);
    });

    // The same line, repeated in `updateWithdrawRequest`: a seller editing a pending request meets the same crash.
    testWidgets(
        'that is edited into a 422 throws the same way and tells the seller nothing, which is a defect',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        _walletServer(<ScriptedAnswer>[
          errorsRefusal('amount', _aboveWithdrawableText, status: 422)
        ]),
      );
      await flow.fillTheSheet(tester);

      final Object? thrown = await FlowHarness.callThatThrows(tester,
          () => flow.wallet.updateWithdrawRequest('9999', 21, Get.context!));

      expect(thrown, isA<NoSuchMethodError>(),
          reason:
              'what happens today. It should be null, with the server\'s words shown');
      expect(toasts, isEmpty,
          reason:
              'what the seller reads today. It should be ["$_aboveWithdrawableText"]');
      expect(flow.wallet.isLoading, isTrue,
          reason: 'the sheet is left loading. It should be false');
      expect(FlowHarness.screenIsOpen(tester), isTrue);
    });

    testWidgets(
        'may be edited while it is pending: a POST to the update address with the request\'s id',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        _walletServer(<ScriptedAnswer>[
          ScriptedAnswer.json('Withdraw request update successfully!')
        ]),
      );
      await flow.fillTheSheet(tester);

      await FlowHarness.call(tester,
          () => flow.wallet.updateWithdrawRequest('200.0', 21, Get.context!));

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _withdrawUpdatePath);
      expect(request.fields, <String, Object?>{
        'account_number': '9876543210',
        'holder_name': 'Test Holder',
        'amount': '200.0',
        'withdraw_method_id': '2',
        'withdraw_request_id': '21',
      });
      expect(FlowHarness.screenIsOpen(tester), isFalse);
    });

    testWidgets(
        'may be closed while it is pending: a POST of the delete the API reads, and the balance is read again',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        _walletServer(<ScriptedAnswer>[
          ScriptedAnswer.json('Withdraw request closed successfully')
        ]),
      );

      final ApiResponse answer = await FlowHarness.call(
          tester, () => flow.wallet.closeWithdrawRequest(21, '150.5'));

      final RecordedRequest request = flow.adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.path, _closePath);
      expect(request.fields, <String, Object?>{
        '_method': 'delete',
        'amount': '150.5',
        'id': '21'
      });
      FlowHarness.expectSignedIn(request);
      expect(answer.response!.statusCode, 200);
      expect(flow.profile.balancesGivenBack, <String>['150.5'],
          reason: 'the amount goes back to the balance the seller sees');
      expect(flow.shop.shopReads, 1);
      expect(flow.wallet.isLoading, isFalse);
    });

    testWidgets(
        'that is refused when it is closed is answered as a failure and leaves the balance alone',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          _walletServer(
              <ScriptedAnswer>[messageRefusal(_invalidWithdrawText)]));

      final ApiResponse answer = await FlowHarness.call(
          tester, () => flow.wallet.closeWithdrawRequest(21, '150.5'));

      expect(answer.response, isNull);
      expect(answer.error, _invalidWithdrawText);
      expect(flow.profile.balancesGivenBack, isEmpty);
      expect(flow.shop.shopReads, 0);
      expect(flow.wallet.isLoading, isFalse);
    });
  });

  group('the list of withdrawal requests', () {
    testWidgets(
        'is a GET of the status and the dates the screen holds, signed in',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.always(
            ScriptedAnswer.json(<Object?>[withdrawalJson()])),
      );

      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _transactionsPath);
      expect(flow.adapter.only.query,
          <String, String>{'status': 'all', 'from': '', 'to': ''});
      expect(flow.adapter.only.body, isNull);
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    // The tabs say pending, approved and denied; the API reads pending, approve and deny.
    const Map<int, String> statusOfTab = <int, String>{
      0: 'all',
      1: 'pending',
      2: 'approve',
      3: 'deny'
    };

    for (final MapEntry<int, String> tab in statusOfTab.entries) {
      testWidgets(
          'asks for the status "${tab.value}" when the seller opens tab ${tab.key}',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
            tester, ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])));

        await FlowHarness.call(tester,
            () async => flow.transactions.setIndex(Get.context!, tab.key));

        expect(flow.adapter.only.query['status'], tab.value);
      });
    }

    testWidgets(
        'asks for the dates the seller chose, written the way the API reads them',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])));

      await FlowHarness.call(
        tester,
        () => flow.transactions.applyDateRange(
            Get.context!, DateTime(2026, 11, 1), DateTime(2026, 11, 15)),
      );

      expect(flow.adapter.only.query, <String, String>{
        'status': 'all',
        'from': '2026-11-01',
        'to': '2026-11-15'
      });
      expect(flow.transactions.hasDateFilter, isTrue);
    });

    testWidgets(
        'is what the screen reads: each request with its amount, its state and its method',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[
          withdrawalJson(),
          withdrawalJson(id: 20, amount: 80, approved: 1)
        ])),
      );

      expect(flow.transactions.transactionList, isNull);

      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(
          flow.transactions.transactionList!
              .map((transaction) => transaction.id),
          <int?>[21, 20]);
      expect(
          flow.transactions.transactionList!
              .map((transaction) => transaction.amount),
          <double?>[150.5, 80.0]);
      expect(
          flow.transactions.transactionList!
              .map((transaction) => transaction.approved),
          <int?>[0, 1]);
      expect(
          flow.transactions.transactionList!.first
              .withdrawalMethodFields!['account_number'],
          '9876543210');
      expect(flow.transactions.isLoading, isFalse);
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets('may be empty, which is an answer and not a failure',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, ScriptedAdapter.always(ScriptedAnswer.json(<Object?>[])));

      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(flow.transactions.transactionList, isEmpty);
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets(
        'that is refused is shown in the server\'s words and leaves the list empty',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, ScriptedAdapter.always(permissionRefusal()));

      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.transactions.transactionList, isNull);
      expect(flow.transactions.isLoading, isFalse);
    });

    testWidgets(
        'that fails in transport is shown, throws nothing, and can be asked for again',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.timeout(),
          ScriptedAnswer.json(<Object?>[withdrawalJson()])
        ]),
      );

      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      expect(flow.transactions.transactionList, isNull);
      expect(flow.transactions.isLoading, isFalse);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.call(
          tester,
          () => flow.transactions
              .getTransactionList(Get.context!, 'all', '', ''));

      expect(flow.transactions.transactionList!.single.id, 21);
    });
  });

  group('the ledger\'s payouts', () {
    testWidgets('are read with a GET, ten requests at a time, signed in',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester, ScriptedAdapter.always(ScriptedAnswer.json(payoutsJson())));

      await FlowHarness.call(tester, flow.payouts.getPayouts);

      expect(flow.adapter.only.method, 'GET');
      expect(flow.adapter.only.path, _payoutsPath);
      expect(flow.adapter.only.query,
          <String, String>{'limit': '10', 'offset': '1'});
      expect(flow.adapter.only.body, isNull);
      FlowHarness.expectSignedIn(flow.adapter.only);
    });

    testWidgets(
        'show the buckets of the account, what may be withdrawn, and each request with its state',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.always(
            ScriptedAnswer.json(payoutsJson(requests: <Map<String, Object?>>[
          payoutRequestJson(),
          payoutRequestJson(id: 4, status: 'paid', amount: 40),
        ]))),
      );

      expect(flow.payouts.payouts, isNull);

      await FlowHarness.call(tester, flow.payouts.getPayouts);

      expect(flow.payouts.payouts!.withdrawable, 598);
      expect(flow.payouts.payouts!.reserved, 102);
      expect(flow.payouts.payouts!.payoutCurrencies, <String>['SYP', 'USD']);
      expect(flow.payouts.payouts!.requests.map((request) => request.id),
          <int?>[5, 4]);
      expect(flow.payouts.payouts!.requests.first.isOpen, isTrue,
          reason: 'a request still open may be cancelled');
      expect(flow.payouts.payouts!.requests.last.isOpen, isFalse,
          reason: 'a paid request may not');
      expect(FlowHarness.shown(tester), isEmpty);
    });

    testWidgets(
        'that are refused are shown in the server\'s words and leave the screen as it was',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.json(payoutsJson()),
          permissionRefusal()
        ]),
      );
      await FlowHarness.call(tester, flow.payouts.getPayouts);

      await FlowHarness.call(tester, flow.payouts.getPayouts);

      expect(FlowHarness.shown(tester), <String>[permissionRefusalText]);
      expect(flow.payouts.payouts!.withdrawable, 598);
    });

    testWidgets(
        'that fail in transport are shown, throw nothing, and can be read again',
        (WidgetTester tester) async {
      final _WithdrawFlow flow = await _WithdrawFlow.pump(
        tester,
        ScriptedAdapter.inOrder(<ScriptedAnswer>[
          ScriptedAnswer.offline(),
          ScriptedAnswer.json(payoutsJson())
        ]),
      );

      await FlowHarness.call(tester, flow.payouts.getPayouts);

      expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
      expect(flow.payouts.payouts, isNull);

      await FlowHarness.dismissToast(tester);
      await FlowHarness.call(tester, flow.payouts.getPayouts);

      expect(flow.payouts.payouts!.withdrawable, 598);
    });

    group('a request', () {
      /// A ledger that remembers what was asked: the request shows in the list and takes its amount off what may be withdrawn.
      ScriptedAdapter ledger({ScriptedAnswer? request}) {
        final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
        num withdrawable = 598;

        return ScriptedAdapter.routes(<String, ScriptedServer>{
          'POST $_payoutsPath': (RecordedRequest incoming) {
            if (request != null) return request;
            final num amount = incoming.fields['amount']! as num;
            requests.add(payoutRequestJson(amount: amount));
            withdrawable -= amount;
            return ScriptedAnswer.json(<String, Object?>{
              'status': true,
              'message': 'Payout requested',
              'request': requests.last
            });
          },
          'GET $_payoutsPath': (_) => ScriptedAnswer.json(
              payoutsJson(requests: requests, withdrawable: withdrawable)),
          'GET $_overviewPath': (_) => ScriptedAnswer.json(
              sellerCenterOverviewJson(withdrawable: withdrawable)),
        });
      }

      testWidgets(
          'is a POST of the amount, the method and the currency the seller chose, signed in',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(tester, ledger());

        await FlowHarness.call(
          tester,
          () => flow.payouts.requestPayout(
              amount: 150.5, method: 'bank_transfer', payoutCurrency: 'SYP'),
        );

        final RecordedRequest request = flow.adapter.requests.first;
        expect(request.method, 'POST');
        expect(request.path, _payoutsPath);
        expect(request.rawQuery, isEmpty);
        expect(request.fields, <String, Object?>{
          'amount': 150.5,
          'method': 'bank_transfer',
          'payout_currency': 'SYP'
        });
        FlowHarness.expectSignedIn(request);
      });

      testWidgets(
          'leaves out the method and the currency the seller did not choose',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(tester, ledger());

        await FlowHarness.call(
            tester,
            () => flow.payouts
                .requestPayout(amount: 80, method: '', payoutCurrency: null));

        expect(flow.adapter.requests.first.fields,
            <String, Object?>{'amount': 80});
      });

      testWidgets(
          'that was accepted is told to the seller in the server\'s words, and the list and the overview are read again',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(tester, ledger());

        final bool requested = await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 150.5));

        expect(requested, isTrue);
        expect(FlowHarness.shown(tester), <String>['Payout requested']);
        expect(
          flow.adapter.requests
              .map((request) => '${request.method} ${request.path}'),
          <String>[
            'POST $_payoutsPath',
            'GET $_payoutsPath',
            'GET $_overviewPath'
          ],
        );
        expect(flow.payouts.payouts!.requests.single.amount, 150.5,
            reason: 'the new request shows in the list');
        expect(flow.payouts.payouts!.withdrawable, 447.5,
            reason: 'and the amount comes off what may be withdrawn');
        expect(flow.payouts.overview!.finance!.withdrawable, 447.5);
        expect(flow.payouts.isSubmitting, isFalse);
      });

      testWidgets(
          'that the server refuses is shown in its words, answers false, and reads nothing again',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
            tester, ledger(request: messageRefusal(_aboveWithdrawableText)));

        final bool requested = await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 9000));

        expect(requested, isFalse);
        expect(FlowHarness.shown(tester), <String>[_aboveWithdrawableText]);
        expect(flow.adapter.requests, hasLength(1));
        expect(flow.payouts.isSubmitting, isFalse,
            reason: 'the button the seller pressed is usable again');
      });

      testWidgets(
          'that the server refuses with a key the app has is shown in the app\'s words',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(tester,
            ledger(request: messageRefusal('kyc_verification_required')));

        await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 100));

        expect(FlowHarness.shown(tester), <String>[_enKycRequired]);
      });

      testWidgets('that fails validation is shown in the server\'s words',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          ledger(
              request:
                  errorsRefusal('amount', 'The amount must be at least 0.01.')),
        );

        await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 0));

        expect(FlowHarness.shown(tester),
            <String>['The amount must be at least 0.01.']);
      });

      testWidgets(
          'that fails in transport is shown, answers false, throws nothing, and can be sent again',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          ScriptedAdapter.inOrder(<ScriptedAnswer>[
            ScriptedAnswer.offline(),
            ScriptedAnswer.json(<String, Object?>{
              'status': true,
              'message': 'Payout requested',
              'request': payoutRequestJson()
            }),
            ScriptedAnswer.json(payoutsJson(
                requests: <Map<String, Object?>>[payoutRequestJson()],
                withdrawable: 447.5)),
            ScriptedAnswer.json(sellerCenterOverviewJson(withdrawable: 447.5)),
          ]),
        );

        final bool requested = await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 150.5));

        expect(requested, isFalse);
        expect(FlowHarness.shown(tester), <String>[_enNoInternet]);
        expect(flow.payouts.isSubmitting, isFalse);
        expect(flow.adapter.requests, hasLength(1),
            reason: 'nothing is read again after a failure');

        await FlowHarness.dismissToast(tester);
        final bool again = await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 150.5));

        expect(again, isTrue);
        expect(
            flow.adapter.requests[1].fields, flow.adapter.requests.first.fields,
            reason: 'the retry is the same request');
        expect(flow.payouts.payouts!.requests.single.amount, 150.5);
      });

      testWidgets(
          'that fails when the connection never completes is shown in words',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
            tester, ledger(request: ScriptedAnswer.timeout()));

        await FlowHarness.call(
            tester, () => flow.payouts.requestPayout(amount: 150.5));

        expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      });
    });

    group('a cancellation', () {
      testWidgets(
          'is a POST to the request\'s own address with no body, and the list and the overview are read again',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          ScriptedAdapter.routes(<String, ScriptedServer>{
            'POST $_cancelPayoutPath': (_) =>
                ScriptedAnswer.json(<String, Object?>{
                  'status': true,
                  'message': 'Payout request cancelled'
                }),
            'GET $_payoutsPath': (_) => ScriptedAnswer.json(payoutsJson()),
            'GET $_overviewPath': (_) =>
                ScriptedAnswer.json(sellerCenterOverviewJson()),
          }),
        );

        await FlowHarness.call(tester, () => flow.payouts.cancelPayout(5));

        expect(flow.adapter.requests.first.method, 'POST');
        expect(flow.adapter.requests.first.path, _cancelPayoutPath);
        expect(flow.adapter.requests.first.body, isNull);
        FlowHarness.expectSignedIn(flow.adapter.requests.first);
        expect(FlowHarness.shown(tester), <String>['Payout request cancelled']);
        expect(
          flow.adapter.requests
              .map((request) => '${request.method} ${request.path}'),
          <String>[
            'POST $_cancelPayoutPath',
            'GET $_payoutsPath',
            'GET $_overviewPath'
          ],
        );
        expect(flow.payouts.payouts!.requests, isEmpty);
      });

      testWidgets(
          'that the server refuses is shown in its words and reads nothing again',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
          tester,
          ScriptedAdapter.always(
              messageRefusal('This payout can no longer be cancelled.')),
        );

        await FlowHarness.call(tester, () => flow.payouts.cancelPayout(5));

        expect(FlowHarness.shown(tester),
            <String>['This payout can no longer be cancelled.']);
        expect(flow.adapter.requests, hasLength(1));
      });

      testWidgets('that fails in transport is shown and throws nothing',
          (WidgetTester tester) async {
        final _WithdrawFlow flow = await _WithdrawFlow.pump(
            tester, ScriptedAdapter.always(ScriptedAnswer.timeout()));

        await FlowHarness.call(tester, () => flow.payouts.cancelPayout(5));

        expect(FlowHarness.shown(tester), <String>[_enTimeout]);
      });
    });
  });
}
