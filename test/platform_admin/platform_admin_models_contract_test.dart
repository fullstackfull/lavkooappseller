import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_audit_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_market_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_overview_models.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_session_models.dart';

import 'support/fixtures.dart';

/// Every shape the platform admin API answers with, parsed from the body the
/// real controllers produced (see `support/fixtures.dart`).
///
/// What matters more than any one figure: a market with nothing in it still
/// has a card, a field the server leaves null stays absent instead of becoming
/// a zero, a key the app has never heard of is ignored, and no amount of money
/// can come out of a model that never had a place to keep one.
void main() {
  group('sign-in and who is signed in', () {
    test(
        'the sign-in answer carries the token once, its expiry and who signed in',
        () {
      final PlatformAdminSignIn signIn =
          PlatformAdminSignIn.fromJson(fixtureData('login_success'));

      expect(signIn.token, fixtureToken);
      expect(signIn.expiresAt, DateTime.utc(2026, 11, 17, 14));
      expect(signIn.profile.adminId, 4);
      expect(signIn.profile.level, 1);
      expect(signIn.profile.scope, PlatformScope.all);
      expect(
          signIn.profile.markets, <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
      expect(signIn.profile.tokenExpiresAt, signIn.expiresAt);
    });

    test(
        'the sign-in answer does not give its token to anything that prints it',
        () {
      final PlatformAdminSignIn signIn =
          PlatformAdminSignIn.fromJson(fixtureData('login_success'));

      expect(signIn.toString(), isNot(contains(fixtureToken)));
      expect('$signIn', isNot(contains('lkpa_')));
    });

    test(
        'the platform owner is not restricted and may see every market the server lists',
        () {
      final PlatformAdminProfile owner =
          PlatformAdminProfile.fromJson(fixtureData('me_owner'));

      expect(owner.isRestricted, isFalse);
      expect(owner.canSee('KW'), isTrue);
      expect(owner.canSee('all'), isTrue);
    });

    test(
        'a restricted viewer sees only what the server lists, and nothing the app guesses',
        () {
      final PlatformAdminProfile viewer =
          PlatformAdminProfile.fromJson(fixtureData('me_restricted'));

      expect(viewer.scope, PlatformScope.restricted);
      expect(viewer.isRestricted, isTrue);
      expect(viewer.markets, <String>['AE', 'KW']);
      expect(viewer.canSee('KW'), isTrue);
      expect(viewer.canSee('SA'), isFalse);
      expect(viewer.canSee('all'), isTrue,
          reason: 'all means all of theirs and is never refused');
    });

    test('a viewer whose grant names no market that exists sees none', () {
      final PlatformAdminProfile viewer =
          PlatformAdminProfile.fromJson(fixtureData('me_no_markets'));

      expect(viewer.isRestricted, isTrue);
      expect(viewer.markets, isEmpty);
      expect(viewer.canSee('KW'), isFalse);
    });

    test(
        'a scope the app does not know is treated as restricted, never as the owner',
        () {
      final PlatformAdminProfile profile = PlatformAdminProfile.fromJson(
        <String, dynamic>{...fixtureData('me_owner'), 'scope': 'galaxy'},
      );

      expect(profile.scope, PlatformScope.restricted);
    });

    test('a missing scope is restricted too', () {
      final Map<String, dynamic> body = fixtureData('me_owner')
        ..remove('scope');

      expect(PlatformAdminProfile.fromJson(body).isRestricted, isTrue);
    });

    test(
        'a token that never expires is read as no expiry and not as a date in 1970',
        () {
      final Map<String, dynamic> body = fixtureData('me_owner')
        ..['token_expires_at'] = null;

      expect(PlatformAdminProfile.fromJson(body).tokenExpiresAt, isNull);
    });

    test(
        'a sign-in answer with no token has an empty token that the caller can refuse',
        () {
      final PlatformAdminSignIn signIn = PlatformAdminSignIn.fromJson(
        <String, dynamic>{
          'token_type': 'Bearer',
          'me': fixtureData('me_owner')
        },
      );

      expect(signIn.token, isEmpty);
    });
  });

  group('sessions', () {
    test('lists the open sessions newest first and marks the one in use', () {
      final List<PlatformSessionModel> sessions = fixtureRows('sessions_owner')
          .map(PlatformSessionModel.fromJson)
          .toList();

      expect(sessions.map((PlatformSessionModel session) => session.deviceName),
          <String>['Pixel 9', 'Owner iPad', 'Owner iPhone']);
      expect(sessions.map((PlatformSessionModel session) => session.isCurrent),
          <bool>[false, false, true]);
      expect(sessions.last.id, 1);
      expect(sessions.last.createdAt, DateTime.utc(2026, 11, 17, 4));
      expect(sessions.last.lastUsedAt, DateTime.utc(2026, 11, 17, 6));
      expect(sessions.last.expiresAt, DateTime.utc(2026, 11, 17, 14));
    });

    test(
        'a session that was never used has no last use, which is not the same as the moment it opened',
        () {
      final PlatformSessionModel session =
          PlatformSessionModel.fromJson(fixtureRows('sessions_owner').first);

      expect(session.lastUsedAt, isNull);
      expect(session.createdAt, isNotNull);
    });
  });

  group('markets', () {
    test(
        'the owner lists the six markets in the order the server configured them',
        () {
      final PlatformMarketDirectory directory =
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner'));

      expect(directory.scope, PlatformScope.all);
      expect(directory.generatedAt, DateTime.utc(2026, 11, 17, 6));
      expect(directory.codes, <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
      expect(
          directory.markets
              .map((PlatformMarketModel market) => market.currency),
          <String>['SAR', 'AED', 'KWD', 'QAR', 'BHD', 'OMR']);
    });

    test('active, storefronts and legal readiness are three separate facts',
        () {
      final PlatformMarketDirectory directory =
          PlatformMarketDirectory.fromJson(fixtureData('markets_owner'));
      final PlatformMarketModel kuwait = directory.markets
          .firstWhere((PlatformMarketModel market) => market.code == 'KW');
      final PlatformMarketModel qatar = directory.markets
          .firstWhere((PlatformMarketModel market) => market.code == 'QA');

      expect(kuwait.active, isTrue);
      expect(kuwait.storefrontEnabled, isTrue);
      expect(kuwait.legalReady, isFalse,
          reason: 'active, but its legal documents are not approved');
      expect(qatar.active, isFalse);
      expect(qatar.legalReady, isFalse);
      expect(kuwait.legalEntity, 'Lavkoo Trading Co.');
      expect(kuwait.path, 'kw');
    });

    test('a restricted viewer lists only their markets', () {
      final PlatformMarketDirectory directory =
          PlatformMarketDirectory.fromJson(fixtureData('markets_restricted'));

      expect(directory.scope, PlatformScope.restricted);
      expect(directory.codes, <String>['AE', 'KW']);
    });

    test('a viewer with no market lists none', () {
      final PlatformMarketDirectory directory =
          PlatformMarketDirectory.fromJson(fixtureData('markets_none'));

      expect(directory.markets, isEmpty);
      expect(directory.scope, PlatformScope.restricted);
    });

    test('a market the server has no legal entity for has none', () {
      final Map<String, dynamic> body = fixtureData('markets_owner');
      (body['markets'] as List)
          .cast<Map<String, dynamic>>()
          .first['legal_entity'] = null;

      expect(PlatformMarketDirectory.fromJson(body).markets.first.legalEntity,
          isNull);
    });

    test(
        'a market that is missing a switch is off and not ready, never silently on',
        () {
      final PlatformMarketModel market =
          PlatformMarketModel.fromJson(<String, dynamic>{'code': 'SA'});

      expect(market.active, isFalse);
      expect(market.storefrontEnabled, isFalse);
      expect(market.legalReady, isFalse);
    });
  });

  group('overview', () {
    late PlatformOverviewModel owner;

    setUp(() => owner =
        PlatformOverviewModel.fromJson(fixtureData('overview_owner_all')));

    test('says who asked, for what, and when it was counted', () {
      expect(owner.scope, PlatformScope.all);
      expect(owner.market, 'all');
      expect(owner.generatedAt, DateTime.utc(2026, 11, 17, 6));
      expect(owner.freshness.mode, 'live');
      expect(owner.freshness.cached, isFalse);
    });

    test('the window is what the server resolved, not what the app asked for',
        () {
      expect(owner.window!.from, '2026-10-19');
      expect(owner.window!.to, '2026-11-17');
      expect(owner.window!.days, 30);
      expect(owner.window!.clamped, isFalse);
      expect(owner.window!.timezone, 'Asia/Dhaka');
    });

    test('a window the server cut says so', () {
      final PlatformOverviewModel cut = PlatformOverviewModel.fromJson(
          fixtureData('overview_owner_window_clamped'));

      expect(cut.window!.clamped, isTrue);
      expect(cut.window!.days, 92);
      expect(cut.window!.from, '2026-08-18');
    });

    test('a window of a week is a week', () {
      final PlatformOverviewModel week = PlatformOverviewModel.fromJson(
          fixtureData('overview_owner_window_7'));

      expect(week.window!.days, 7);
      expect(week.window!.from, '2026-11-11');
    });

    test(
        'every market of the owner has a card, in the configured order, with nothing hidden for being empty',
        () {
      expect(
          owner.markets.map((PlatformMarketOverview market) => market.market),
          <String>['SA', 'AE', 'KW', 'QA', 'BH', 'OM']);
      expect(
          owner.markets.map(
              (PlatformMarketOverview market) => market.storefrontCurrency),
          <String?>['SAR', 'AED', 'KWD', 'QAR', 'BHD', 'OMR']);
      expect(
          owner.markets.map((PlatformMarketOverview market) => market.active),
          <bool>[true, true, true, false, false, false]);
    });

    test(
        'Saudi Arabia: five orders by status, the backlog, refund requests, stock and alerts, as the backend counted them',
        () {
      final PlatformMarketOverview saudi = owner.marketOf('SA')!;

      expect(saudi.figures.orders.total, 5);
      expect(saudi.figures.orders.byStatus, <String, int>{
        'pending': 1,
        'confirmed': 1,
        'processing': 1,
        'out_for_delivery': 0,
        'delivered': 2,
        'returned': 0,
        'failed': 0,
        'canceled': 0,
      });
      expect(saudi.figures.orders.latestAt, DateTime.utc(2026, 11, 17, 12));
      expect(saudi.figures.pendingFulfilment, 4);
      expect(saudi.figures.refundRequests, 2);
      expect(saudi.figures.refundRequestsPending, 1);
      expect(saudi.figures.stockZero, 1);
      expect(saudi.figures.stockLow, 3);
      expect(saudi.alerts.critical, 0);
      expect(saudi.alerts.warning, 0);
      expect(saudi.alerts.info, 1);
      expect(saudi.alerts.total, 1);
    });

    test('statuses keep the order the server sent them in', () {
      expect(
        owner.marketOf('KW')!.figures.orders.byStatus.keys.toList(),
        <String>[
          'pending',
          'confirmed',
          'processing',
          'out_for_delivery',
          'delivered',
          'returned',
          'failed',
          'canceled'
        ],
      );
    });

    test(
        'a market with no order has no latest order, and zeros rather than absences',
        () {
      final PlatformMarketOverview qatar = owner.marketOf('QA')!;

      expect(qatar.figures.orders.total, 0);
      expect(qatar.figures.orders.latestAt, isNull);
      expect(
          qatar.figures.orders.byStatus.values.every((int count) => count == 0),
          isTrue);
      expect(qatar.figures.pendingFulfilment, 0);
      expect(qatar.alerts.total, 0);
    });

    test(
        'a status the app has never heard of is counted under its own name, after the known ones',
        () {
      final PlatformOverviewModel other = PlatformOverviewModel.fromJson(
          fixtureData('overview_owner_unknown_status'));
      final Map<String, int> byStatus =
          other.marketOf('SA')!.figures.orders.byStatus;

      expect(byStatus['on_hold'], 1);
      expect(byStatus.keys.last, 'on_hold');
      expect(byStatus.values.fold<int>(0, (int sum, int count) => sum + count),
          other.marketOf('SA')!.figures.orders.total);
    });

    test(
        'an empty list of statuses that arrives as [] is an empty map and not a failure',
        () {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      ((body['markets'] as List).first as Map<String, dynamic>)['orders']
          ['by_status'] = <Object?>[];

      expect(
          PlatformOverviewModel.fromJson(body)
              .markets
              .first
              .figures
              .orders
              .byStatus,
          isEmpty);
    });

    test(
        'the owner asking for all markets also gets the orders that belong to no single market, kept apart',
        () {
      final PlatformUnattributedOverview unattributed = owner.unattributed!;

      expect(unattributed.reason, 'no_single_market');
      expect(unattributed.figures.orders.total, 4);
      expect(unattributed.figures.orders.byStatus['pending'], 2);
      expect(unattributed.figures.pendingFulfilment, 3);
      expect(unattributed.figures.refundRequests, 2);
      expect(unattributed.figures.refundRequestsPending, 1);
      expect(unattributed.figures.stockZero, 1);
      expect(
          owner.markets.map((PlatformMarketOverview market) => market.market),
          isNot(contains(null)),
          reason: 'the bucket is not one of the markets');
    });

    test(
        'one market alone has no unattributed bucket, which might belong to a market the viewer may not see',
        () {
      final PlatformOverviewModel kuwait =
          PlatformOverviewModel.fromJson(fixtureData('overview_owner_kw'));

      expect(kuwait.market, 'KW');
      expect(
          kuwait.markets.map((PlatformMarketOverview market) => market.market),
          <String>['KW']);
      expect(kuwait.unattributed, isNull);
    });

    test(
        'a restricted viewer asking for all sees theirs, says so, and has no bucket',
        () {
      final PlatformOverviewModel viewer = PlatformOverviewModel.fromJson(
          fixtureData('overview_restricted_all'));

      expect(viewer.scope, PlatformScope.restricted);
      expect(viewer.market, 'all');
      expect(
          viewer.markets.map((PlatformMarketOverview market) => market.market),
          <String>['AE', 'KW']);
      expect(viewer.unattributed, isNull);
    });

    test('a viewer with no market gets an overview with no market', () {
      final PlatformOverviewModel viewer =
          PlatformOverviewModel.fromJson(fixtureData('overview_no_markets'));

      expect(viewer.markets, isEmpty);
      expect(viewer.unattributed, isNull);
      expect(viewer.scope, PlatformScope.restricted);
    });

    test(
        'marketOf finds a market by its code and says nothing for one that is not there',
        () {
      expect(owner.marketOf('KW')!.market, 'KW');
      expect(owner.marketOf('ZZ'), isNull);
    });

    test(
        'keys the app has never heard of, anywhere in the answer, change nothing',
        () {
      final Map<String, dynamic> noisy =
          _withUnknownKeysEverywhere(fixtureData('overview_owner_all'));
      final PlatformOverviewModel parsed =
          PlatformOverviewModel.fromJson(noisy);

      expect(_summary(parsed), _summary(owner));
    });

    test(
        'an answer with no sections at all is an empty overview and not an exception',
        () {
      final PlatformOverviewModel empty =
          PlatformOverviewModel.fromJson(const <String, dynamic>{});

      expect(empty.markets, isEmpty);
      expect(empty.unattributed, isNull);
      expect(empty.window, isNull);
      expect(empty.scope, PlatformScope.restricted);
    });

    test('a figure that arrives as the wrong type is zero and not an exception',
        () {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      final Map<String, dynamic> saudi =
          (body['markets'] as List).first as Map<String, dynamic>;
      saudi['orders']['total'] = 'many';
      saudi['stock'] = 'none';
      saudi['pending_fulfilment'] = null;

      final PlatformMarketOverview parsed =
          PlatformOverviewModel.fromJson(body).markets.first;

      expect(parsed.figures.orders.total, 0);
      expect(parsed.figures.stockZero, 0);
      expect(parsed.figures.pendingFulfilment, 0);
    });

    test(
        'a count that arrives as a whole number in a string is read as that number',
        () {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      ((body['markets'] as List).first as Map<String, dynamic>)['orders']
          ['total'] = '7';

      expect(
          PlatformOverviewModel.fromJson(body)
              .markets
              .first
              .figures
              .orders
              .total,
          7);
    });
  });

  group('money is never reported', () {
    test(
        'every market and the bucket say why there is no sales figure, and carry no amount',
        () {
      final PlatformOverviewModel overview =
          PlatformOverviewModel.fromJson(fixtureData('overview_owner_all'));

      for (final PlatformMarketOverview market in overview.markets) {
        expect(market.figures.sales.reason, 'order_currency_not_recorded',
            reason: market.market);
      }
      expect(overview.unattributed!.figures.sales.reason,
          'order_currency_not_recorded');
    });

    test(
        'an answer that one day carries amounts still gives the app nothing to show but a reason',
        () {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      final Map<String, dynamic> saudi =
          (body['markets'] as List).first as Map<String, dynamic>;
      saudi['sales'] = <String, dynamic>{
        'by_currency': <Object?>[
          <String, dynamic>{
            'market': 'SA',
            'currency': 'SAR',
            'total': 1234567.89,
            'orders': 5
          },
        ],
        'reason': null,
      };

      final PlatformSalesFigure sales =
          PlatformOverviewModel.fromJson(body).markets.first.figures.sales;

      expect(sales.reason, isNull);
      expect(sales.toString(), isNot(contains('1234567')));
      expect(sales.toString(), isNot(contains('SAR')));
    });

    test('a missing sales section is a missing reason and not an invented one',
        () {
      final Map<String, dynamic> body = fixtureData('overview_owner_all');
      ((body['markets'] as List).first as Map<String, dynamic>).remove('sales');

      expect(
          PlatformOverviewModel.fromJson(body)
              .markets
              .first
              .figures
              .sales
              .reason,
          isNull);
    });
  });

  group('alerts', () {
    test(
        'lists the alerts worst first as the server sorted them, with the fields the app routes on',
        () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner'), fixtureMeta('alerts_owner'));

      expect(
          page.alerts.map((PlatformAlertModel alert) =>
              '${alert.severity} ${alert.market} ${alert.code}'),
          <String>[
            'critical KW legal_not_ready',
            'warning KW stock_zero',
            'info SA orders_pending_too_long',
            'info KW orders_pending_too_long',
          ]);
      expect(page.alerts.first.id, 'a4882d780c5c00a1');
      expect(page.alerts.first.deepLink, 'markets/KW');
      expect(page.alerts.first.generatedAt, DateTime.utc(2026, 11, 17, 6));
      expect(page.alerts[1].message, '2 live products in KW are out of stock.');
    });

    test('says how it was asked and how many there are', () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner'), fixtureMeta('alerts_owner'));

      expect(page.scope, PlatformScope.all);
      expect(page.market, 'all');
      expect(page.severity, isNull);
      expect(page.page, 1);
      expect(page.perPage, 25);
      expect(page.total, 4);
      expect(page.hasMore, isFalse);
      expect(page.generatedAt, DateTime.utc(2026, 11, 17, 6));
    });

    test('a page with more says so, and the next page says it is the last', () {
      final PlatformAlertPage first = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner_page_1_of_2'),
          fixtureMeta('alerts_owner_page_1_of_2'));
      final PlatformAlertPage second = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner_page_2_of_2'),
          fixtureMeta('alerts_owner_page_2_of_2'));

      expect(first.alerts, hasLength(3));
      expect(first.hasMore, isTrue);
      expect(first.total, 4);
      expect(second.alerts, hasLength(1));
      expect(second.page, 2);
      expect(second.hasMore, isFalse);
    });

    test('a market with nothing wrong has no alert', () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner_qa_none'),
          fixtureMeta('alerts_owner_qa_none'));

      expect(page.alerts, isEmpty);
      expect(page.total, 0);
      expect(page.market, 'QA');
    });

    test('the severity filter is echoed back', () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          fixtureRows('alerts_owner_critical'),
          fixtureMeta('alerts_owner_critical'));

      expect(page.severity, 'critical');
      expect(
          page.alerts.map((PlatformAlertModel alert) => alert.severity).toSet(),
          <String>{'critical'});
    });

    test('a restricted viewer is told the list is restricted', () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          fixtureRows('alerts_restricted'), fixtureMeta('alerts_restricted'));

      expect(page.scope, PlatformScope.restricted);
      expect(
          page.alerts.map((PlatformAlertModel alert) => alert.market).toSet(),
          <String>{'KW'});
    });

    test(
        'a severity the app does not know ranks below info and is kept as it came',
        () {
      final PlatformAlertModel alert =
          PlatformAlertModel.fromJson(<String, dynamic>{
        ...fixtureRows('alerts_owner').first,
        'severity': 'catastrophic',
      });

      expect(alert.severity, 'catastrophic');
      expect(PlatformSeverity.rank('catastrophic'),
          lessThan(PlatformSeverity.rank('info')));
      expect(PlatformSeverity.rank('critical'),
          greaterThan(PlatformSeverity.rank('warning')));
      expect(PlatformSeverity.rank('warning'),
          greaterThan(PlatformSeverity.rank('info')));
    });

    test('keys the app has never heard of change nothing', () {
      final List<Map<String, dynamic>> rows =
          fixtureRows('alerts_owner').map(_withUnknownKeysEverywhere).toList();
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          rows, _withUnknownKeysEverywhere(fixtureMeta('alerts_owner')));

      expect(
          page.alerts.map((PlatformAlertModel alert) => alert.id),
          fixtureRows('alerts_owner')
              .map((Map<String, dynamic> row) => row['id']));
      expect(page.total, 4);
    });

    test('an answer with no list and no meta is an empty page', () {
      final PlatformAlertPage page = PlatformAlertPage.fromJson(
          const <Map<String, dynamic>>[], const <String, dynamic>{});

      expect(page.alerts, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.scope, PlatformScope.restricted);
    });
  });

  group('deep links', () {
    test('markets/XX opens that market', () {
      expect(PlatformDeepLink.parse('markets/KW')?.market, 'KW');
    });

    test('the code is upper-cased, as the server writes it', () {
      expect(PlatformDeepLink.parse('markets/kw')?.market, 'KW');
    });

    test(
        'a link the app cannot route is no link, so a tile built from it is not tappable',
        () {
      for (final String? link in <String?>[
        null,
        '',
        'markets',
        'markets/',
        'markets/KW/orders',
        'orders/12',
        'https://example.test/markets/KW',
        '/markets/KW',
        'markets/K W',
        'markets/../me'
      ]) {
        expect(PlatformDeepLink.parse(link), isNull, reason: '$link');
      }
    });

    test('every alert of the real answer links to its own market', () {
      for (final PlatformAlertModel alert in PlatformAlertPage.fromJson(
              fixtureRows('alerts_owner'), fixtureMeta('alerts_owner'))
          .alerts) {
        expect(alert.link?.market, alert.market);
      }
    });
  });

  group('audit log', () {
    test(
        'lists the lines newest first, each with the action, who and where it came from',
        () {
      final PlatformAuditPage page = PlatformAuditPage.fromJson(
          fixtureRows('audit_logs_owner_page_1_of_n'),
          fixtureMeta('audit_logs_owner_page_1_of_n'));

      expect(page.lines.map((PlatformAuditLine line) => line.id),
          <int>[33, 32, 31, 30, 29]);
      expect(page.lines.first.action, 'audit_logs.view');
      expect(page.lines.first.adminId, 4);
      expect(page.lines.first.ip, '127.0.0.1');
      expect(page.lines.first.createdAt, DateTime.utc(2026, 11, 17, 6));
      expect(page.hasMore, isTrue);
      expect(page.page, 1);
      expect(page.perPage, 5);
      expect(page.scope, PlatformScope.all);
    });

    test(
        'a request line carries the status the API answered with, and the market asked about',
        () {
      final PlatformAuditPage page = PlatformAuditPage.fromJson(
          fixtureRows('audit_logs_owner'), fixtureMeta('audit_logs_owner'));
      final PlatformAuditLine refused = page.lines.firstWhere(
          (PlatformAuditLine line) =>
              line.market == 'SA' && line.statusCode == 403);

      expect(refused.action, 'overview.view');
      expect(refused.adminId, 5);
    });

    test(
        'a line written by the operator at the console has no address and no agent',
        () {
      final PlatformAuditPage page = PlatformAuditPage.fromJson(
          fixtureRows('audit_logs_owner_page_1_of_n'),
          fixtureMeta('audit_logs_owner_page_1_of_n'));
      final PlatformAuditLine grant = page.lines.firstWhere(
          (PlatformAuditLine line) => line.action == 'grant.created');

      expect(grant.ip, isNull);
      expect(grant.userAgent, isNull);
      expect(grant.statusCode, isNull);
    });

    test('a restricted viewer is told the list is theirs alone', () {
      final PlatformAuditPage page = PlatformAuditPage.fromJson(
          fixtureRows('audit_logs_restricted'),
          fixtureMeta('audit_logs_restricted'));

      expect(page.scope, PlatformScope.restricted);
      expect(page.lines.map((PlatformAuditLine line) => line.adminId).toSet(),
          <int?>{5});
    });

    test('a line the server wrote with no actor is attributed to nobody', () {
      final PlatformAuditLine line =
          PlatformAuditLine.fromJson(<String, dynamic>{
        ...fixtureRows('audit_logs_owner').first,
        'admin_id': null
      });

      expect(line.adminId, isNull);
    });

    test(
        'a sign-in line carries the name of the device and nothing else of its context',
        () {
      final PlatformAuditLine line =
          PlatformAuditLine.fromJson(<String, dynamic>{
        'id': 9,
        'admin_id': 4,
        'action': 'auth.login',
        'context': <String, dynamic>{'device_name': 'Pixel 9'},
        'created_at': '2026-11-17T06:00:00Z',
      });

      expect(line.deviceName, 'Pixel 9');
      expect(line.statusCode, isNull);
    });

    test('a context that is not an object is no context', () {
      final PlatformAuditLine line =
          PlatformAuditLine.fromJson(<String, dynamic>{
        ...fixtureRows('audit_logs_owner').first,
        'context': 'text'
      });

      expect(line.statusCode, isNull);
      expect(line.deviceName, isNull);
    });

    test('an action the app has not heard of is kept as it came', () {
      final PlatformAuditLine line =
          PlatformAuditLine.fromJson(<String, dynamic>{
        ...fixtureRows('audit_logs_owner').first,
        'action': 'exports.create'
      });

      expect(line.action, 'exports.create');
    });

    test('a page beyond the end is empty and has no more', () {
      final PlatformAuditPage page = PlatformAuditPage.fromJson(
          const <Map<String, dynamic>>[],
          <String, dynamic>{
            'scope': 'all',
            'page': 1000,
            'per_page': 100,
            'has_more': false
          });

      expect(page.lines, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.page, 1000);
    });
  });
}

/// Adds a key the app has never heard of to every object in the tree, except
/// `by_status`, whose keys are not a schema: a new key there is a new status.
Map<String, dynamic> _withUnknownKeysEverywhere(Map<String, dynamic> source) {
  Object? walk(Object? node, {bool addsKey = true}) {
    if (node is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in node.entries)
          entry.key as String:
              walk(entry.value, addsKey: entry.key != 'by_status'),
        if (addsKey)
          'zz_future_field': <String, dynamic>{
            'nested': <Object?>[1, 'two', null]
          },
      };
    }
    if (node is List) {
      return node.map(walk).toList();
    }
    return node;
  }

  return walk(jsonDecode(jsonEncode(source))) as Map<String, dynamic>;
}

/// Everything an overview says, in one comparable string.
String _summary(PlatformOverviewModel overview) {
  String figures(PlatformFigures figures) =>
      '${figures.orders.total}/${figures.orders.byStatus}/${figures.orders.latestAt}'
      '/${figures.pendingFulfilment}/${figures.refundRequests}/${figures.refundRequestsPending}/${figures.stockZero}/${figures.stockLow}'
      '/${figures.stockOversold}/${figures.stockOversoldUnits}'
      '/${figures.reserved?.holds}-${figures.reserved?.units}/${figures.allocation?.pools}-${figures.allocation?.short}-${figures.allocation?.shortUnits}'
      '/${figures.sales.reason}';

  return <String>[
    overview.scope.name,
    overview.market,
    '${overview.generatedAt}',
    '${overview.window?.from}-${overview.window?.to}-${overview.window?.days}-${overview.window?.clamped}-${overview.window?.timezone}',
    '${overview.freshness.mode}-${overview.freshness.cached}',
    for (final PlatformMarketOverview market in overview.markets)
      '${market.market}/${market.storefrontCurrency}/${market.active}/${figures(market.figures)}/${market.alerts.critical}-${market.alerts.warning}-${market.alerts.info}',
    if (overview.unattributed != null)
      'unattributed/${overview.unattributed!.reason}/${figures(overview.unattributed!.figures)}',
  ].join('|');
}
