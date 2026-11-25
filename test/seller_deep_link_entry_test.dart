import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/notification/models/notification_body.dart';
import 'package:syriacosmeticsmanger/notification/seller_deep_link_entry.dart';

/// K-11.4: the plumbing that brings a `lavkooseller://` link in.
///
/// The decision about where a link opens is [SellerDeepLink]'s and is tested in `seller_deep_link_test.dart`. What is tested here is the part
/// that is easy to get wrong and invisible when it is: a link that is not ours opening something anyway, a link opening twice because the app
/// subscribed twice, and a failure in the stream taking the app down while the seller is working.
void main() {
  tearDown(SellerDeepLinkEntry.stopListening);

  group('the link that started the app', () {
    test('its payload is the one the link names', () async {
      final NotificationBody? payload = await SellerDeepLinkEntry.initialPayload(
        link: Future<Uri?>.value(Uri.parse('lavkooseller://order/4242')),
      );

      expect(payload?.orderId, 4242);
    });

    test('no link, a link that is not ours, and a link that cannot be read all answer nothing', () async {
      expect(await SellerDeepLinkEntry.initialPayload(link: Future<Uri?>.value()), isNull);
      expect(await SellerDeepLinkEntry.initialPayload(link: Future<Uri?>.value(Uri.parse('https://lavkoo.com/order/1'))), isNull);
      expect(
        await SellerDeepLinkEntry.initialPayload(link: Future<Uri?>.error(StateError('no platform here'))),
        isNull,
        reason: 'a link that cannot be read must cost the app nothing -- the seller opened their shop',
      );
    });
  });

  group('a link that arrives while the app is running', () {
    test('it opens what it names, and a link that is not ours opens nothing', () async {
      final StreamController<Uri> links = StreamController<Uri>();
      final List<int?> opened = <int?>[];

      SellerDeepLinkEntry.listen(onPayload: (NotificationBody payload) => opened.add(payload.orderId), links: links.stream);

      links.add(Uri.parse('lavkooseller://order/4242'));
      links.add(Uri.parse('https://lavkoo.com/order/9'));
      links.add(Uri.parse('lavkooseller://order'));
      links.add(Uri.parse('lavkooseller://order/7'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, <int?>[4242, 7]);
      await links.close();
    });

    test('taking up a new source drops the old one, so one link is never opened twice', () async {
      final StreamController<Uri> first = StreamController<Uri>.broadcast();
      final StreamController<Uri> second = StreamController<Uri>.broadcast();
      int opened = 0;

      SellerDeepLinkEntry.listen(onPayload: (_) => opened++, links: first.stream);
      SellerDeepLinkEntry.listen(onPayload: (_) => opened++, links: second.stream);

      first.add(Uri.parse('lavkooseller://order/1'));
      second.add(Uri.parse('lavkooseller://order/2'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, 1, reason: 'only the source taken up last is listened to');
      await first.close();
      await second.close();
    });

    test('a failure in the stream opens nothing and does not throw', () async {
      final StreamController<Uri> links = StreamController<Uri>();
      int opened = 0;

      SellerDeepLinkEntry.listen(onPayload: (_) => opened++, links: links.stream);

      links.addError(StateError('the platform sent nonsense'));
      links.add(Uri.parse('lavkooseller://order/5'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, 1, reason: 'the error is swallowed and the next link still opens');
      await links.close();
    });

    test('stopping means a later link opens nothing', () async {
      final StreamController<Uri> links = StreamController<Uri>();
      int opened = 0;

      SellerDeepLinkEntry.listen(onPayload: (_) => opened++, links: links.stream);
      SellerDeepLinkEntry.stopListening();

      links.add(Uri.parse('lavkooseller://order/1'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, 0);
      await links.close();
    });
  });
}
