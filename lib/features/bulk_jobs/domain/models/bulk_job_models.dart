/// A bulk job as the server describes it.
///
/// The receipt is the point of this feature, so the model keeps the counts and
/// the refused rows rather than collapsing them into a single "succeeded" flag.
/// A run that changed 380 of 400 products has to be able to say which 20 it did
/// not change, and why.
class BulkJobModel {
  final int id;
  final String type;
  final String status;
  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final int progress;
  final bool isFinished;
  final String? error;
  final String? createdAt;
  final String? finishedAt;
  final List<BulkJobFailure> failures;

  const BulkJobModel({
    required this.id,
    required this.type,
    required this.status,
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.progress,
    required this.isFinished,
    this.error,
    this.createdAt,
    this.finishedAt,
    this.failures = const <BulkJobFailure>[],
  });

  factory BulkJobModel.fromJson(Map<String, dynamic> json) => BulkJobModel(
        id: _int(json['id']),
        type: json['type']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        total: _int(json['total']),
        processed: _int(json['processed']),
        succeeded: _int(json['succeeded']),
        failed: _int(json['failed']),
        progress: _int(json['progress']),
        isFinished: json['is_finished'] == true,
        error: json['error']?.toString(),
        createdAt: json['created_at']?.toString(),
        finishedAt: json['finished_at']?.toString(),
        failures: json['failures'] is List
            ? List<Map<String, dynamic>>.from((json['failures'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)))
                .map(BulkJobFailure.fromJson)
                .toList()
            : const <BulkJobFailure>[],
      );

  /// A job that ran to the end and refused some rows. Not an error — the rest of
  /// the work landed, and the failure list says what did not.
  bool get isPartial => status == 'partial';

  bool get isRunning => !isFinished;

  static int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}

/// One row the job did not change, with the reason in the seller's own language.
///
/// Both the key and the sentence are kept: the key is what a client branches on,
/// the sentence is what a person reads.
class BulkJobFailure {
  final int? productId;
  final String? name;
  final String? reason;
  final String message;

  const BulkJobFailure({this.productId, this.name, this.reason, required this.message});

  factory BulkJobFailure.fromJson(Map<String, dynamic> json) => BulkJobFailure(
        productId: json['product_id'] is int ? json['product_id'] as int : int.tryParse(json['product_id']?.toString() ?? ''),
        name: json['name']?.toString(),
        reason: json['reason']?.toString(),
        message: json['message']?.toString() ?? '',
      );
}

/// A page of the seller's own bulk jobs.
class BulkJobListModel {
  final int totalSize;
  final List<BulkJobModel> jobs;

  const BulkJobListModel({required this.totalSize, required this.jobs});

  factory BulkJobListModel.fromJson(Map<String, dynamic> json) => BulkJobListModel(
        totalSize: BulkJobModel._int(json['total_size']),
        jobs: json['jobs'] is List
            ? (json['jobs'] as List)
                .whereType<Map>()
                .map((row) => BulkJobModel.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const <BulkJobModel>[],
      );
}
