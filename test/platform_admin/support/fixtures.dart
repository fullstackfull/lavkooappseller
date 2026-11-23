import 'dart:convert';
import 'dart:io';

/// The bodies the real platform admin controllers answered, recorded verbatim.
///
/// They were captured by running the backend's own platform admin test world
/// (backend branch `wf/gcc20-platform`) against the real controllers and saving
/// every answer byte for byte, so these tests parse what the server says and
/// not a transcription of what its documentation says. The only change made to
/// them is the sign-in token, which is replaced by an obviously fake one.
///
/// The fixtures marked with a `source` in `index.json` are the exception: they were
/// written by hand from the contract, `docs/gcc/GCC-20-PLATFORM-ADMIN-API.md` of the
/// backend, delivery 2 (the second factor, the capabilities, ending the other
/// sessions, the new audit actions), because the backend's test world was not run
/// again to record them. A test that parses one of those proves that the app reads
/// the contract, not that the server says it. They are to be replaced by recordings.
///
/// `index.json` holds what the body alone cannot say: the status and, for a
/// throttled answer, the `Retry-After` header.
const String _directory = 'test/platform_admin/fixtures';

String rawFixture(String name) => File('$_directory/$name.json').readAsStringSync();

Map<String, dynamic> fixture(String name) => jsonDecode(rawFixture(name)) as Map<String, dynamic>;

/// What is inside `data` of a successful answer.
Map<String, dynamic> fixtureData(String name) => Map<String, dynamic>.from(fixture(name)['data'] as Map);

/// The rows of `data` of a successful list answer.
List<Map<String, dynamic>> fixtureRows(String name) =>
    (fixture(name)['data'] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();

/// What a list answer says about itself.
Map<String, dynamic> fixtureMeta(String name) => Map<String, dynamic>.from(fixture(name)['meta'] as Map);

int fixtureStatus(String name) => _index()[name]!['status'] as int;

String? fixtureRetryAfter(String name) => _index()[name]!['retry_after'] as String?;

/// Where a fixture that was not recorded comes from, or null for one that was.
String? fixtureSource(String name) => _index()[name]!['source'] as String?;

/// Every fixture there is.
List<String> fixtureNames() => _index().keys.toList();

Map<String, dynamic> _index() {
  final Map<String, dynamic> decoded =
      jsonDecode(File('$_directory/index.json').readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((String name, Object? entry) => MapEntry(name, Map<String, dynamic>.from(entry as Map)));
}

/// The sign-in token the fixtures carry, to look for in places it must never be.
const String fixtureToken = 'lkpa_TESTTOKEN0123456789TESTTOKEN0123456789TESTTOKEN0123456789TESTTOK';

/// The challenge of the second step the fixtures carry, to look for in places it must never be.
const String fixtureChallenge = 'lkpc_TESTCHALLENGE0123456789TESTCHALLENGE0123456789AB';
