import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/utill/app_constants.dart';

/// Where the seller's session token may be named in the source, read from the source itself (K-12).
///
/// A behaviour test proves that today's code keeps the token in the Keystore. This proves the code has no WAY back to plaintext: the key
/// `AppConstants.token` is an unencrypted entry in SharedPreferences, which survives a device backup and is readable on a rooted or cloned device,
/// and a seller's token opens their whole shop -- orders, customers, payouts. `SellerSessionToken` moved it to the platform secure store and
/// migrates what an older build left behind.
///
/// What the move did NOT leave behind is a guard. Three files name the key today, each for a reason recorded below, and a fourth reader added
/// tomorrow would quietly put the session back where it started: nothing would fail, and `SellerSessionToken`'s own docblock would simply stop being
/// true of the application. The original fix found THREE readers where it expected one, which is the measurement that says a list is worth keeping.
///
/// Comments are stripped before the scan, because a sentence explaining why the key must not be read is not a reading of it. And the key is matched
/// at a WORD BOUNDARY, not as a substring: `AppConstants.tokenUri` -- the Firebase token route -- begins with `AppConstants.token`, so a substring
/// scan refuses a file for naming a URL. Measured: today the one file that names `tokenUri` happens to be a permitted one, so a substring scan would
/// pass by luck and refuse the next legitimate caller.
void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File left, File right) => left.path.compareTo(right.path));

  /// The lines of every file with their number, comments left out.
  final Map<String, List<(int, String)>> code = <String, List<(int, String)>>{
    for (final File file in sources)
      file.path.replaceAll(r'\', '/'): <(int, String)>[
        for (final (int index, String line) in file.readAsLinesSync().indexed)
          if (!line.trimLeft().startsWith('//'))
            (index + 1, line.replaceAll(RegExp(r'//.*$'), '')),
      ],
  };

  /// The file that OWNS the key: the store, which reads it to migrate, removes
  /// it once it has, and writes it only on a device whose secure storage
  /// cannot be written to at all -- a recorded trade-off, so that a seller is
  /// never locked out by their own phone.
  const String store = 'lib/data/datasource/local/seller_session_token.dart';

  /// The key itself, at a word boundary so that `AppConstants.tokenUri` is not
  /// read as a naming of it.
  final RegExp legacyKey = RegExp(r'AppConstants\.token\b');

  /// The files that may name the key besides the store, and why each may.
  const Map<String, String> permitted = <String, String>{
    'lib/data/datasource/remote/dio/dio_client.dart':
        'reads it ONLY when no session store was injected -- an unwired build '
            'or test -- because the Authorization header is built '
            'synchronously in the constructor and the secure store is async; '
            'a wired client reads the store',
    'lib/features/auth/domain/repositories/auth_repository.dart':
        'REMOVES it at sign-out, belt and braces beside '
            'SellerSessionToken.clear(); a remove can only ever delete a '
            'token, never surface one',
  };

  /// Every line of a file outside the allowed set that names the pattern.
  List<String> offencesOutside(Set<String> allowed, Pattern forbidden) =>
      <String>[
        for (final MapEntry<String, List<(int, String)>> file in code.entries)
          if (!allowed.contains(file.key))
            for (final (int, String) line in file.value)
              if (line.$2.contains(forbidden))
                '${file.key}:${line.$1}  ${line.$2.trim()}',
      ];

  test('the sources and the store are read, or no rule below proves anything',
      () {
    expect(sources, isNotEmpty);
    expect(code.keys, contains(store));
    expect(
      code[store]!.where(((int, String) line) => line.$2.contains(legacyKey)),
      isNotEmpty,
      reason: 'the store must still name the key it owns, or this file is '
          'scanning for the wrong constant',
    );
  });

  test('nothing outside the store writes the token to the plain file', () {
    expect(
      offencesOutside(
          <String>{store}, RegExp(r'setString\(AppConstants\.token\b')),
      isEmpty,
      reason: 'a token written to SharedPreferences is a token in an '
          'unencrypted file that survives a device backup. The store writes '
          'it there only when the Keystore itself cannot be written to, '
          'which is a recorded trade-off; nowhere else may.',
    );
  });

  test('only the store and the two files recorded here name the legacy key',
      () {
    expect(
      offencesOutside(<String>{store, ...permitted.keys}, legacyKey),
      isEmpty,
      reason: 'the session token lives in the platform secure store '
          '(SellerSessionToken). A new file that names the legacy key reaches '
          'past it; read the token from the store, and if the key genuinely '
          'has to be named here, add the file above with the reason.',
    );
  });

  test('every permitted file still exists and still names the key', () {
    for (final String path in permitted.keys) {
      expect(code.keys, contains(path),
          reason: '$path is recorded as a reader of the legacy key and does '
              'not exist');
      expect(
        code[path]!.where(((int, String) line) => line.$2.contains(legacyKey)),
        isNotEmpty,
        reason: '$path no longer names the legacy key, so its entry is stale '
            'and would excuse whatever is named that next',
      );
    }
  });

  test('the key the scan looks for is the one a session is stored under', () {
    expect(AppConstants.token, isNotEmpty);
    expect(AppConstants.token, isNot(AppConstants.tokenUri),
        reason: 'the scan must not be matching the Firebase token ROUTE, '
            'which is a different constant that merely starts the same way');
  });
}
