import 'package:barcode_scan2/gen/protos/protos.pbenum.dart';

/// The barcode symbologies the camera reads when a cashier scans a product: the retail codes a pharmacy's packs carry (EAN-13, EAN-8, UPC-E) and the shop's own Code 128 labels. An earlier version
/// listed Code 128 alone, so a retail pack could not be scanned at all. A UPC-A code is read as an EAN-13 with a leading zero, which is how the scanning libraries of both platforms report it, so
/// it is covered by EAN-13 (the plugin has no format of its own for it).
const List<BarcodeFormat> productBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upce,
  BarcodeFormat.code128,
];
