// Fails when a translation key used in the code is missing from a language
// file, or when the language files have drifted apart.
//
// Run with: dart run tool/check_translations.dart
import 'dart:convert';
import 'dart:io';

const List<String> _languages = <String>['en', 'ar'];

/// Keys resolved at runtime (status names, guideline keys, camelCase-derived
/// keys) never appear as a literal, so they cannot be checked statically.
final RegExp _usagePattern = RegExp(r"""getTranslated\(\s*(['"])([A-Za-z0-9_ ]+?)\1""");

Future<int> main() async {
  final Map<String, Map<String, dynamic>> files = <String, Map<String, dynamic>>{};
  for (final String code in _languages) {
    final File file = File('assets/language/$code.json');
    if (!file.existsSync()) {
      stderr.writeln('MISSING language file: ${file.path}');
      return 1;
    }
    files[code] = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  final Set<String> used = <String>{};
  await for (final FileSystemEntity entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final String source = await entity.readAsString();
    for (final RegExpMatch match in _usagePattern.allMatches(source)) {
      used.add(match.group(2)!);
    }
  }

  int problems = 0;

  for (final String code in _languages) {
    final Map<String, dynamic> map = files[code]!;

    final List<String> whitespaceKeys = map.keys.where((k) => k != k.trim()).toList();
    if (whitespaceKeys.isNotEmpty) {
      stderr.writeln('$code.json has keys with stray whitespace: $whitespaceKeys');
      problems += whitespaceKeys.length;
    }

    final List<String> missing = used.where((k) => !map.containsKey(k)).toList()..sort();
    if (missing.isNotEmpty) {
      stderr.writeln('$code.json is missing ${missing.length} key(s) used in code:');
      for (final String key in missing) {
        stderr.writeln('  $key');
      }
      problems += missing.length;
    }
  }

  final Set<String> reference = files[_languages.first]!.keys.toSet();
  for (final String code in _languages.skip(1)) {
    final Set<String> keys = files[code]!.keys.toSet();
    final List<String> onlyInReference = reference.difference(keys).toList()..sort();
    final List<String> onlyInThis = keys.difference(reference).toList()..sort();
    if (onlyInReference.isNotEmpty) {
      stderr.writeln('$code.json is missing ${onlyInReference.length} key(s) present in ${_languages.first}.json: $onlyInReference');
      problems += onlyInReference.length;
    }
    if (onlyInThis.isNotEmpty) {
      stderr.writeln('$code.json has ${onlyInThis.length} key(s) not in ${_languages.first}.json: $onlyInThis');
      problems += onlyInThis.length;
    }
  }

  if (problems == 0) {
    stdout.writeln('Translations OK: ${used.length} keys used, ${reference.length} keys defined per language.');
    return 0;
  }
  stderr.writeln('\n$problems translation problem(s) found.');
  exit(1);
}
