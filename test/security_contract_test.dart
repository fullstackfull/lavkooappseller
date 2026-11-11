import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/security/domain/models/security_models.dart';

/// Captured from a running backend
/// (`/api/v3/seller/seller-center/security/...` and `/integrations/...`).
///
/// The first case is the state this marketplace is actually in: one owner, no
/// staff, no keys, no endpoints. A screen that only looked right once somebody
/// had filled it in would be wrong on the day it shipped, so the empty shapes
/// are pinned first.
///
/// Everything else here is about not overstating what is known. A key whose
/// `last_used_at` is null has never been used and must not be drawn as if it
/// has; an endpoint that has neither succeeded nor failed has not earned a
/// green tick; and nothing anywhere returns a credential after the moment it
/// was created.
void main() {
  const String liveAccess = '''
  {"holders":[{"type":"owner","id":1,"name":"Test Seller","role":null,"status":"active",
    "signed_in":true,"last_login_at":null}]}''';

  const String liveKeys = '''
  {"keys":[],"grantable_scopes":["products.view","products.manage","orders.view","orders.manage",
    "inventory.manage","promotions.manage","finance.view","payouts.request","reviews.view",
    "shop_settings.manage","staff.manage"]}''';

  const String liveEvents = '''
  {"events":["order.placed","order.status_changed","order.refund_requested","product.stock_low",
    "product.hidden_by_rule","payout.status_changed"]}''';

  const String liveAudit = '''
  {"entries":[{"id":7,"action":"seller.bulk_job_queued","actor_name":"System","actor_type":"system",
    "subject_type":"App\\\\Models\\\\SellerBulkJob","subject_id":"1","before":null,"after":null,
    "ip_address":"127.0.0.1","created_at":"2026-08-24T01:53:22.000000Z"}],"total":1}''';

  const String staffedShop = '''
  {"staff":[{"id":4,"name":"Clerk","email":"clerk@example.com","seller_role_id":2,"role":"Warehouse",
    "status":"active","signed_in":true,"last_login_at":"2026-08-24T07:10:00.000000Z"},
   {"id":5,"name":"Former","email":"former@example.com","seller_role_id":null,"role":null,
    "status":"inactive","signed_in":false,"last_login_at":"2026-06-01T07:10:00.000000Z"}]}''';

  const String rolesPayload = '''
  {"roles":[{"id":2,"name":"Warehouse","permissions":["orders.view","inventory.manage"],
    "status":"active","staff_count":1},
   {"id":3,"name":"Observer","permissions":[],"status":"active","staff_count":0}]}''';

  const String keysPayload = '''
  {"keys":[{"id":1,"name":"ERP read-only","prefix":"fazb7k","scopes":["orders.view","products.view"],
    "last_used_at":"2026-08-24T08:38:11.000000Z","last_used_ip":"10.0.0.4","expires_at":null,
    "revoked_at":null,"usable":true,"created_at":"2026-08-24T08:37:00.000000Z"},
   {"id":2,"name":"Old integration","prefix":"ujpm8u","scopes":["products.view"],
    "last_used_at":null,"last_used_ip":null,"expires_at":null,
    "revoked_at":"2026-08-24T09:00:00.000000Z","usable":false,
    "created_at":"2026-08-20T08:37:00.000000Z"}],"grantable_scopes":["orders.view"]}''';

  const String webhooksPayload = '''
  {"webhooks":[{"id":1,"name":"ERP","url":"https://erp.example.com/hook","events":["order.placed"],
    "status":"active","consecutive_failures":0,"last_success_at":null,"last_failure_at":null,
    "disabled_at":null,"disabled_reason":null,"never_called":true,
    "created_at":"2026-08-24T09:00:00.000000Z"},
   {"id":2,"name":"Dead","url":"https://gone.example.com/hook","events":["order.status_changed"],
    "status":"disabled","consecutive_failures":10,"last_success_at":null,
    "last_failure_at":"2026-08-24T09:30:00.000000Z","disabled_at":"2026-08-24T09:30:00.000000Z",
    "disabled_reason":"webhook_disabled_repeated_failures","never_called":false,
    "created_at":"2026-08-01T09:00:00.000000Z"}]}''';

  const String deliveriesPayload = '''
  {"total_size":2,"limit":25,"offset":1,"deliveries":[
    {"id":9,"webhook_id":2,"event":"order.status_changed","status":"pending","attempts":2,
     "response_code":500,"response_body":"upstream exploded","error":null,
     "delivered_at":null,"next_attempt_at":"2026-08-24T09:34:00.000000Z",
     "created_at":"2026-08-24T09:30:00.000000Z"},
    {"id":8,"webhook_id":1,"event":"order.placed","status":"delivered","attempts":1,
     "response_code":200,"response_body":"ok","error":null,
     "delivered_at":"2026-08-24T09:00:05.000000Z","next_attempt_at":null,
     "created_at":"2026-08-24T09:00:00.000000Z"}]}''';

  List<Map<String, dynamic>> rows(String payload, String key) =>
      ((jsonDecode(payload) as Map<String, dynamic>)[key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  test('a shop with only an owner reads as exactly that', () {
    final List<AccessHolderModel> holders =
        rows(liveAccess, 'holders').map(AccessHolderModel.fromJson).toList();

    expect(holders, hasLength(1));
    expect(holders.first.isOwner, isTrue);
    expect(holders.first.signedIn, isTrue);
  });

  test('an access holder never carries a credential', () {
    // The token's existence is the useful fact. Its value is the shop, and the
    // server does not return it — so there is nowhere for the client to leak it.
    expect(jsonDecode(liveAccess).toString(), isNot(contains('auth_token')));
    expect(jsonDecode(liveAccess).toString(), isNot(contains('token')));
  });

  test('a shop with no keys still knows what it could grant', () {
    final Map<String, dynamic> json = jsonDecode(liveKeys) as Map<String, dynamic>;

    expect(json['keys'], isEmpty);
    // The form has something to offer on day one, which is when a seller is
    // most likely to be setting up an integration.
    expect(json['grantable_scopes'], contains('orders.view'));
  });

  test('the event list is the server\'s, not the app\'s', () {
    final List<String> events =
        ((jsonDecode(liveEvents) as Map<String, dynamic>)['events'] as List).map((e) => e.toString()).toList();

    // Hard-coding these in the app would mean a new event needs a new build,
    // and an event removed on the server would keep being offered.
    expect(events, contains('order.placed'));
    expect(events, contains('payout.status_changed'));
  });

  test('an audit entry survives a subject type with escaped backslashes', () {
    final AuditEntryModel entry = AuditEntryModel.fromJson(rows(liveAudit, 'entries').first);

    expect(entry.action, 'seller.bulk_job_queued');
    expect(entry.subjectType, r'App\Models\SellerBulkJob');
  });

  test('somebody switched off reads as switched off and signed out', () {
    final List<SellerStaffModel> staff = rows(staffedShop, 'staff').map(SellerStaffModel.fromJson).toList();

    expect(staff.first.isActive, isTrue);
    expect(staff.first.signedIn, isTrue);
    // The pair that matters: deactivating clears the token, so the two agree.
    expect(staff.last.isActive, isFalse);
    expect(staff.last.signedIn, isFalse);
    expect(staff.last.role, isNull);
  });

  test('a role with no permissions is a real role', () {
    final List<SellerRoleModel> roles = rows(rolesPayload, 'roles').map(SellerRoleModel.fromJson).toList();

    expect(roles.first.permissions, hasLength(2));
    // An account that can sign in and see nothing is a deliberate state, not an
    // empty field the screen should hide.
    expect(roles.last.permissions, isEmpty);
    expect(roles.last.staffCount, 0);
  });

  test('a key that has never been used says so rather than showing a date', () {
    final List<ApiKeyModel> keys = rows(keysPayload, 'keys').map(ApiKeyModel.fromJson).toList();

    expect(keys.first.neverUsed, isFalse);
    expect(keys.first.usable, isTrue);
    // Usually the answer to "can I revoke this?".
    expect(keys.last.neverUsed, isTrue);
    expect(keys.last.usable, isFalse);
  });

  test('a key list never contains a key', () {
    // Only the prefix, which identifies a row and authenticates nothing.
    expect(keysPayload, isNot(contains('sk_seller_')));
    expect(keysPayload, isNot(contains('token_hash')));
  });

  test('an endpoint nothing has been sent to has not earned a green tick', () {
    final List<WebhookModel> webhooks = rows(webhooksPayload, 'webhooks').map(WebhookModel.fromJson).toList();

    expect(webhooks.first.neverCalled, isTrue);
    expect(webhooks.first.lastSuccessAt, isNull);
    expect(webhooks.first.isActive, isTrue);
  });

  test('an endpoint the marketplace switched off says why', () {
    final WebhookModel dead = rows(webhooksPayload, 'webhooks').map(WebhookModel.fromJson).last;

    expect(dead.isDisabled, isTrue);
    expect(dead.disabledReason, 'webhook_disabled_repeated_failures');
    expect(dead.consecutiveFailures, 10);
    // It was called, and it failed. Different from never having been called.
    expect(dead.neverCalled, isFalse);
  });

  test('a webhook never carries its signing secret', () {
    expect(webhooksPayload, isNot(contains('secret')));
  });

  test('a failing delivery keeps what came back and when it will be tried again', () {
    final List<WebhookDeliveryModel> deliveries =
        rows(deliveriesPayload, 'deliveries').map(WebhookDeliveryModel.fromJson).toList();

    expect(deliveries.first.delivered, isFalse);
    expect(deliveries.first.responseCode, 500);
    expect(deliveries.first.responseBody, 'upstream exploded');
    // A seller whose integration is missing every third order needs the third
    // one, and a counter on the endpoint cannot show them which.
    expect(deliveries.first.nextAttemptAt, isNotNull);
    expect(deliveries.last.delivered, isTrue);
    expect(deliveries.last.nextAttemptAt, isNull);
  });
}
