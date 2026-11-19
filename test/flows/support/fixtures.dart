import 'scripted_adapter.dart';

/// The words of the refusals below, as the server writes them. They are not keys of the app's language files, so the
/// app can only show them by passing them through.
const String permissionRefusalText = 'Your role does not allow this action.';

/// What the seller middleware answers a staff member whose role does not reach a route.
ScriptedAnswer permissionRefusal([String message = permissionRefusalText]) => errorsRefusal('permission', message);

/// A refusal in the `errors` list shape the API uses for validation and for rules.
ScriptedAnswer errorsRefusal(String code, String message, {int status = 403}) => ScriptedAnswer.json(
      <String, Object?>{
        'errors': <Object?>[
          <String, Object?>{'code': code, 'message': message},
        ],
      },
      status: status,
    );

/// A refusal in the `message` shape the older seller endpoints use.
ScriptedAnswer messageRefusal(String message,
        {int status = 403, Map<String, Object?> extra = const <String, Object?>{}}) =>
    ScriptedAnswer.json(<String, Object?>{...extra, 'message': message}, status: status);

/// What a proxy or a crashed server sends in place of the API's own answer.
ScriptedAnswer get crashedServer =>
    const ScriptedAnswer.page('<html><body><h1>500 Internal Server Error</h1></body></html>');

/// An order as `orders/list` and `orders/{id}` send it: the fields the app reads, in the shapes the server sends them.
Map<String, Object?> orderJson({
  int id = 1001,
  String orderStatus = 'pending',
  String paymentStatus = 'unpaid',
  num orderAmount = 150.5,
  String customerName = 'Test Customer',
  String shippingResponsibility = 'inhouse_shipping',
}) =>
    <String, Object?>{
      'id': id,
      'customer_id': 55,
      'customer_type': 'customer',
      'payment_status': paymentStatus,
      'order_status': orderStatus,
      'payment_method': 'cash_on_delivery',
      'order_amount': orderAmount,
      'paid_amount': 0,
      'shipping_cost': 10,
      'discount_amount': 0,
      'order_type': 'default_type',
      'shipping_responsibility': shippingResponsibility,
      'created_at': '2026-11-10T09:30:00.000000Z',
      'updated_at': '2026-11-10T09:30:00.000000Z',
      'customer': <String, Object?>{
        'id': 55,
        'name': customerName,
        'f_name': 'Test',
        'l_name': 'Customer',
        'phone': '+10000000000'
      },
      'is_guest': false,
    };

Map<String, Object?> orderPageJson(List<Map<String, Object?>> orders, {int? totalSize, int offset = 1}) =>
    <String, Object?>{
      'total_size': totalSize ?? orders.length,
      'limit': 10,
      'offset': offset,
      'orders': orders,
    };

/// One line of an order, as `orders/{id}` sends it: the order itself rides on the line.
Map<String, Object?> orderLineJson({
  int orderId = 1001,
  String orderStatus = 'pending',
  String paymentStatus = 'unpaid',
  String shippingResponsibility = 'inhouse_shipping',
}) =>
    <String, Object?>{
      'id': 9001,
      'order_id': orderId,
      'product_id': 7,
      'seller_id': 3,
      'qty': 2,
      'price': 60.25,
      'tax': 0,
      'discount': 0,
      'tax_model': 'exclude',
      'delivery_status': orderStatus,
      'payment_status': paymentStatus,
      'product_details': <String, Object?>{
        'id': 7,
        'name': 'Rose Serum',
        'product_type': 'physical',
        'unit_price': 60.25,
        'purchase_price': 30,
        'discount': 0,
        'current_stock': 12,
      },
      'order': orderJson(
        id: orderId,
        orderStatus: orderStatus,
        paymentStatus: paymentStatus,
        shippingResponsibility: shippingResponsibility,
      ),
    };

/// A product as `products/{seller}/all-products` and the stock lists send it.
Map<String, Object?> productJson({
  int id = 7,
  String name = 'Rose Serum',
  int currentStock = 12,
  int status = 1,
  num unitPrice = 25.5,
}) =>
    <String, Object?>{
      'id': id,
      'added_by': 'seller',
      'user_id': 3,
      'name': name,
      'slug': 'rose-serum',
      'product_type': 'physical',
      'code': 'ABC123',
      'brand_id': 1,
      'category_ids': <Object?>[],
      'unit': 'pc',
      'min_qty': 1,
      'images': <Object?>[],
      'thumbnail': 'rose.png',
      'colors_formatted': <Object?>[],
      'attributes': <Object?>[],
      'choice_options': <Object?>[],
      'variation': <Object?>[],
      'digital_product_file_types': <Object?>[],
      'unit_price': unitPrice,
      'purchase_price': 10,
      'tax': 5,
      'tax_model': 'exclude',
      'tax_type': 'percent',
      'discount': 2,
      'discount_type': 'flat',
      'current_stock': currentStock,
      'status': status,
      'reviews_count': 0,
      'average_review': 0,
    };

Map<String, Object?> productPageJson(List<Map<String, Object?>> products,
        {int? totalSize, int offset = 1, int limit = 20}) =>
    <String, Object?>{
      'total_size': totalSize ?? products.length,
      'limit': limit,
      'offset': offset,
      'products': products,
    };

/// A review as `shop-product-reviews` and `products/review-list/{id}` send it.
Map<String, Object?> reviewJson({
  int id = 31,
  int productId = 7,
  num rating = 4,
  String comment = 'Smells lovely and lasts all day.',
  int status = 1,
  String? reply,
}) =>
    <String, Object?>{
      'id': id,
      'product_id': productId,
      'customer_id': 55,
      'order_id': 1001,
      'comment': comment,
      'rating': rating,
      'status': status,
      'created_at': '2026-11-11T10:00:00.000000Z',
      'updated_at': '2026-11-11T10:00:00.000000Z',
      'product': productJson(id: productId),
      'customer': <String, Object?>{'id': 55, 'name': 'Test Customer', 'f_name': 'Test', 'l_name': 'Customer'},
      'reply':
          reply == null ? null : <String, Object?>{'id': 5, 'review_id': id, 'added_by': 'seller', 'reply_text': reply},
    };

Map<String, Object?> reviewPageJson(List<Map<String, Object?>> reviews, {int? totalSize}) => <String, Object?>{
      'total_size': totalSize ?? reviews.length,
      'limit': '10',
      'offset': '1',
      'reviews': reviews,
    };

/// One request to be told when a product is back, as `restock-request-list` sends it.
Map<String, Object?> restockRowJson({int id = 1, int productId = 7}) => <String, Object?>{
      'id': id,
      'product_id': productId,
      'variant': 'M',
      'restock_product_customers_count': 3,
      'product': productJson(id: productId, currentStock: 0),
      'variant_keys': <Object?>['M'],
    };

Map<String, Object?> restockPageJson(List<Map<String, Object?>> rows) => <String, Object?>{
      'total_size': rows.length,
      'limit': 10,
      'offset': 1,
      'data': rows,
    };

/// The stock ledger's overview, as `seller-center/inventory/overview` sends it.
Map<String, Object?> inventoryOverviewJson({int unitsOnHand = 600}) => <String, Object?>{
      'low_stock_threshold': 5,
      'products': 2,
      'out_of_stock': 0,
      'running_low': 0,
      'units_on_hand': unitsOnHand,
      'movements_recorded': 0,
      'reasons': <Object?>['count_correction', 'damage', 'loss', 'theft', 'found', 'expiry', 'other'],
      'movement_types': <Object?>['adjustment', 'receipt', 'sale', 'return', 'transfer'],
      'warehouses_enabled': false,
      'batches_enabled': false,
    };

/// The ledger's movements, as `seller-center/inventory/movements` sends them.
Map<String, Object?> inventoryMovementsJson({List<int> changes = const <int>[-2]}) => <String, Object?>{
      'total_size': changes.length,
      'limit': 25,
      'offset': 1,
      'movements': <Object?>[
        for (final int change in changes)
          <String, Object?>{
            'id': 3,
            'product_id': 7,
            'type': 'adjustment',
            'qty_change': change,
            'balance_after': 498,
            'reason': 'damage',
            'note': 'Broken in transit',
            'created_by_type': 'seller',
            'created_at': '2026-11-12T02:23:28.000000Z',
          },
      ],
    };

/// A withdrawal method the marketplace offers, as `withdraw-method-list` sends it.
Map<String, Object?> withdrawMethodJson({int id = 2}) => <String, Object?>{
      'id': id,
      'method_name': 'Bank transfer',
      'method_fields': <Object?>[
        <String, Object?>{
          'input_type': 'text',
          'input_name': 'account_number',
          'placeholder': 'Account number',
          'is_required': 1
        },
        <String, Object?>{
          'input_type': 'text',
          'input_name': 'holder_name',
          'placeholder': 'Account holder',
          'is_required': 1
        },
      ],
      'is_default': false,
      'is_active': true,
    };

/// A withdrawal request, as `transactions` lists it.
Map<String, Object?> withdrawalJson({int id = 21, num amount = 150.5, int approved = 0}) => <String, Object?>{
      'id': id,
      'seller_id': 3,
      'admin_id': null,
      'amount': amount,
      'transaction_note': null,
      'approved': approved,
      'created_at': '2026-11-10T09:30:00.000000Z',
      'updated_at': '2026-11-10T09:30:00.000000Z',
      'withdrawal_method_id': 2,
      'withdrawal_method_fields': <String, Object?>{'method_name': 'Bank transfer', 'account_number': '9876543210'},
    };

/// A payout request of the ledger, as `seller-center/payouts` lists it.
Map<String, Object?> payoutRequestJson({int id = 5, String status = 'requested', num amount = 150.5}) =>
    <String, Object?>{
      'id': id,
      'reference': 'PO-20261110-ABC123',
      'amount': amount,
      'currency': 'SYP',
      'status': status,
      'method': 'bank_transfer',
      'created_at': '2026-11-10T09:30:00.000000Z',
    };

/// The payout screen's answer: the account in its buckets, what may be withdrawn, and the requests made.
Map<String, Object?> payoutsJson(
        {List<Map<String, Object?>> requests = const <Map<String, Object?>>[], num withdrawable = 598}) =>
    <String, Object?>{
      'balances': <String, Object?>{
        'available': 700,
        'pending': 0,
        'reserved': 102,
        'paid': 200,
        'balance': withdrawable
      },
      'payout_currencies': <Object?>['SYP', 'USD'],
      'withdrawable': withdrawable,
      'in_cooling_period': false,
      'payout_eligible': true,
      'total_size': requests.length,
      'limit': 10,
      'offset': 1,
      'requests': requests,
    };

/// The seller-center overview the payout screen re-reads after a change.
Map<String, Object?> sellerCenterOverviewJson({num withdrawable = 598}) => <String, Object?>{
      'verification': <String, Object?>{'status': 'verified', 'required_for_payout': false},
      'finance': <String, Object?>{
        'available': 700,
        'pending': 0,
        'balance': withdrawable,
        'withdrawable': withdrawable
      },
      'sla': <String, Object?>{'open_breach_count': 0},
    };
