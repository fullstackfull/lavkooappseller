import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/bulk_jobs/domain/models/bulk_job_models.dart';

/// Captured verbatim from a running backend
/// (`/api/v3/seller/seller-center/bulk-jobs`) against a real database.
///
/// The payload below is a real partial result: three products asked for, two
/// changed, one refused with its reason. That case is the whole reason the
/// receipt exists, so it is the one pinned here.
void main() {
  const String livePartialJob = '''
  {"job":{"id":1,"type":"price_update","status":"partial","total":3,"processed":3,
    "succeeded":2,"failed":1,"progress":100,"is_finished":true,
    "created_at":"2026-08-24T01:53:22.000000Z","started_at":"2026-08-24T01:53:29.000000Z",
    "finished_at":"2026-08-24T01:53:29.000000Z",
    "input":{"product_ids":[3,4,99999],"settings":{"mode":"increase_percent","value":10}},
    "error":null,
    "failures":[{"product_id":99999,"name":null,"reason":"bulk_reason_product_not_found",
      "message":"Product not found in your catalogue"}]}}''';

  group('bulk job contract', () {
    test('parses a real partial result', () {
      final BulkJobModel job = BulkJobModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(livePartialJob)['job'] as Map));

      expect(job.id, 1);
      expect(job.type, 'price_update');
      // Partial is neither success nor failure, and the model has to be able to
      // say so — the rest of the work landed.
      expect(job.status, 'partial');
      expect(job.isPartial, isTrue);
      expect(job.isFinished, isTrue);
      expect(job.isRunning, isFalse);
      expect(job.total, 3);
      expect(job.succeeded, 2);
      expect(job.failed, 1);
      expect(job.progress, 100);
    });

    test('every refused row keeps both the key and the sentence', () {
      final BulkJobModel job = BulkJobModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(livePartialJob)['job'] as Map));

      expect(job.failures, hasLength(1));
      final BulkJobFailure failure = job.failures.first;
      expect(failure.productId, 99999);
      // The key is what a client branches on; the sentence is what a person
      // reads. Dropping either would cost one of the two.
      expect(failure.reason, 'bulk_reason_product_not_found');
      expect(failure.message, 'Product not found in your catalogue');
      // A product that could not be found has no name to show, and the receipt
      // says the id instead rather than inventing one.
      expect(failure.name, isNull);
    });

    test('a queued job reads as still running', () {
      final BulkJobModel job = BulkJobModel.fromJson(jsonDecode('''
      {"id":7,"type":"stock_update","status":"queued","total":40,"processed":0,
       "succeeded":0,"failed":0,"progress":0,"is_finished":false,
       "created_at":"2026-08-24T01:53:22.000000Z","started_at":null,"finished_at":null}'''));

      expect(job.isRunning, isTrue);
      expect(job.failures, isEmpty);
      expect(job.progress, 0);
    });

    test('parses the job list', () {
      final BulkJobListModel list = BulkJobListModel.fromJson(jsonDecode('''
      {"total_size":1,"limit":3,"offset":1,"types":["price_update","stock_update"],
       "jobs":[{"id":1,"type":"price_update","status":"completed","total":2,"processed":2,
         "succeeded":2,"failed":0,"progress":100,"is_finished":true,
         "created_at":"2026-08-24T01:53:22.000000Z"}]}'''));

      expect(list.totalSize, 1);
      expect(list.jobs, hasLength(1));
      expect(list.jobs.first.status, 'completed');
      // The list endpoint does not send failures; that is the single-job
      // endpoint's job, and an absent list is empty rather than null.
      expect(list.jobs.first.failures, isEmpty);
    });

    test('survives a payload with the sections missing', () {
      final BulkJobModel job = BulkJobModel.fromJson(<String, dynamic>{});

      expect(job.id, 0);
      expect(job.failures, isEmpty);
      expect(job.isFinished, isFalse);
    });
  });
}
