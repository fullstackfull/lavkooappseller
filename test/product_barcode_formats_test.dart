import 'dart:io';

import 'package:barcode_scan2/gen/protos/protos.pbenum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_barcode_formats.dart';

/// K-05: the camera of the POS reads the codes a pharmacy's packs carry. It listed Code 128 alone, so a retail pack (EAN-13, EAN-8, UPC-E; a UPC-A is read as an EAN-13 with a leading zero) could not
/// be scanned at all. That the camera really decodes a pack is a check on a device (docs/gcc/STAGING_PLAN.md); this pins what it is asked to read.
void main() {
  test('the camera is asked for the retail codes of a pack and for the shop\'s own Code 128 labels', () {
    expect(productBarcodeFormats, containsAll(<BarcodeFormat>[BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upce, BarcodeFormat.code128]));
  });

  test('it is not asked for a format that is not a product code, and names none twice', () {
    expect(productBarcodeFormats, isNot(contains(BarcodeFormat.unknown)));
    expect(productBarcodeFormats.toSet().length, productBarcodeFormats.length);
  });

  test('the scan reads the list and does not restrict itself to Code 128 again', () {
    final String controller = File('lib/features/pos/controllers/barcode_scan_controller.dart').readAsStringSync();

    expect(controller, contains('restrictFormat: productBarcodeFormats'));
    expect(controller, isNot(contains('restrictFormat: [BarcodeFormat.code128]')));
  });
}
