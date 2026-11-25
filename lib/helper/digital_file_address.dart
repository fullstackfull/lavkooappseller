/// Where a digital file can be fetched from, and whether fetching it carries the seller's credential (K-17).
///
/// A digital product's file used to live in the public storage folder, so every answer that mentioned one carried a public
/// address and anybody with the link had the file. The platform can now keep those files off the public disk
/// (`DIGITAL_FILES_PRIVATE`), and while it does, the answer carries the authenticated route of the AREA THAT ASKED instead
/// (`DigitalFileAddressService`). This app asks `api/v3/seller`, so it is answered one of three routes of its own, each of which
/// needs the credential that every other request of this app carries — and the download path carried none, so the file the
/// platform had just made private would come back 401.
abstract final class DigitalFileAddress {
  /// The routes of this app's own area that stream a digital file to whoever holds a credential of the shop.
  ///
  /// Only three, and only of this app's area: while the private mode is off the answer is a public storage address instead, and
  /// that one needs no credential and must not be given one.
  static const List<String> authenticatedRoutes = <String>[
    '/api/v3/seller/orders/digital-file/',
    '/api/v3/seller/products/digital-file/',
    '/api/v3/seller/products/digital-variation-file/',
  ];

  /// The address to fetch, or null when the answer carries none.
  ///
  /// A file the platform cannot address answers `path: null` beside the status 404. One screen interpolated that null straight
  /// into a string, so the downloader was handed the four letters `null` as a URL and failed with a message about a malformed
  /// address — the same mistake as parsing the word "null" as a number, in another place.
  static String? of(String? answered) {
    final String address = (answered ?? '').trim();

    return address.isEmpty || address == 'null' ? null : address;
  }

  /// The headers a fetch of [answered] must carry.
  ///
  /// The seller's credential goes to this app's own authenticated routes and nowhere else: not to a bucket, not to a CDN, not to
  /// a public storage address on the same host, not over a scheme the app was not built for, and not to another host at all. A
  /// bearer token in somebody else's access log is a session that whoever reads that log can use.
  static Map<String, String> headersFor(String? answered, {required String baseUrl, required String? token}) {
    final String? address = of(answered);
    if (address == null || token == null || token.isEmpty) {
      return const <String, String>{};
    }

    final Uri? asked = Uri.tryParse(address);
    final Uri? own = Uri.tryParse(baseUrl);
    if (asked == null || own == null || !asked.hasAuthority || asked.host != own.host || asked.scheme != own.scheme) {
      return const <String, String>{};
    }
    if (!authenticatedRoutes.any(asked.path.startsWith)) {
      return const <String, String>{};
    }

    return <String, String>{'Authorization': 'Bearer $token'};
  }
}
