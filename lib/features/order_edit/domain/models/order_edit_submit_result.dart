import 'dart:convert';
import 'package:syriacosmeticsmanger/data/model/response/base/api_response.dart';

/// The outcome of an order edit. [failed] is any answer that is not an HTTP 200
/// (no connection, an HTTP error), which the app's usual error handling reports.
enum OrderEditSubmitOutcome { saved, refused, failed }

/// How the seller API answered `edit-order-submit`.
///
/// An edit the server refuses (a product out of stock, an order that can no
/// longer be edited) is answered with HTTP 200 and
/// `{"status": "error", "message": "..."}`, so the status code alone cannot tell
/// a saved edit from a refused one. Any other 200 body is a saved edit, which is
/// also what servers that predate the refusals send.
class OrderEditSubmitResult {
  final OrderEditSubmitOutcome outcome;

  /// The server's own explanation of a refusal; null when it sent none.
  final String? message;

  const OrderEditSubmitResult._(this.outcome, {this.message});

  bool get isSaved => outcome == OrderEditSubmitOutcome.saved;
  bool get isRefused => outcome == OrderEditSubmitOutcome.refused;

  factory OrderEditSubmitResult.fromApiResponse(ApiResponse apiResponse) {
    if (apiResponse.response?.statusCode != 200) {
      return const OrderEditSubmitResult._(OrderEditSubmitOutcome.failed);
    }

    final Map<dynamic, dynamic>? body = _asMap(apiResponse.response?.data);
    final dynamic status = body?['status'];
    if (status is! String || status.trim().toLowerCase() != 'error') {
      return const OrderEditSubmitResult._(OrderEditSubmitOutcome.saved);
    }

    final dynamic message = body?['message'];
    return OrderEditSubmitResult._(
      OrderEditSubmitOutcome.refused,
      message: message is String && message.trim().isNotEmpty ? message.trim() : null,
    );
  }

  /// The body arrives decoded when the server labels it JSON, and as a string
  /// when something in between (a proxy, a PHP notice) does not.
  static Map<dynamic, dynamic>? _asMap(dynamic body) {
    if (body is Map) return body;
    if (body is! String) return null;

    final String trimmed = body.trim();
    if (!trimmed.startsWith('{')) return null;

    try {
      final dynamic decoded = jsonDecode(trimmed);
      return decoded is Map ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
