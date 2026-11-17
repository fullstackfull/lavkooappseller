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

Map<String, dynamic> _index() {
  final Map<String, dynamic> decoded =
      jsonDecode(File('$_directory/index.json').readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((String name, Object? entry) => MapEntry(name, Map<String, dynamic>.from(entry as Map)));
}

/// The sign-in token the fixtures carry, to look for in places it must never be.
const String fixtureToken = 'lkpa_TESTTOKEN0123456789TESTTOKEN0123456789TESTTOKEN0123456789TESTTOK';
