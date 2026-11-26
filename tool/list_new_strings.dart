// Lists the language keys this branch adds, so that a native Arabic reader can
// be handed a sheet of exactly what is new instead of a diff of two
// two-thousand-key JSON files (K-13).
//
// For each added key it prints the Arabic, the English beside it, and the
// screens that show it, because a reader cannot judge a word without knowing
// where it appears: "scan" on a button and "scan" in a help sentence are not
// the same choice.
//
// It also reports, per key, the four things that are wrong often enough to be
// worth naming: no Arabic, no English, Arabic that is character-for-character
// the English (nothing was translated), and a key no screen uses (nothing to
// read it against). None of these fails the run -- this is a sheet to hand
// over, not a gate; tool/check_translations.dart is the gate.
//
// Every statement here is kept short enough that the formatter does not have
// to wrap it, so the file reads the same under the short style this package's
// language version selects and under the newer tall style. A file that is
// clean under only one of them goes red the day the other is used.
//
// Run with:
//   dart tool/list_new_strings.dart
//   dart tool/list_new_strings.dart --base=origin/gcc/development
//   dart tool/list_new_strings.dart --json
import 'dart:convert';
import 'dart:io';

const String _arabic = 'assets/language/ar.json';
const String _english = 'assets/language/en.json';
const String _defaultBase = 'origin/main';
const String _rule =
    '========================================================================';

/// The call that shows a key on a screen. The same pattern
/// tool/check_translations.dart reads usage with, so the two agree about what
/// counts as using a key.
const String _usagePattern = r"""getTranslated\(\s*(['"])([A-Za-z0-9_ ]+?)\1""";
final RegExp _usage = RegExp(_usagePattern);

Future<int> main(List<String> arguments) async {
  final String base = _option(arguments, '--base') ?? _defaultBase;
  final bool asJson = arguments.contains('--json');

  final Map<String, String> arabic = await _read(_arabic);
  final Map<String, String> english = await _read(_english);
  final Map<String, String>? was = await _readAt(base, _arabic);

  if (was == null) {
    stderr.writeln('Cannot read $_arabic at $base. Pass --base=<ref>.');
    return 1;
  }

  final List<String> added = _keysAddedTo(arabic, was);
  final Map<String, List<String>> screens = await _screensShowing(added);
  final List<Map<String, Object?>> sheet = <Map<String, Object?>>[];

  for (final String key in added) {
    final List<String> shownOn = screens[key] ?? const <String>[];
    final String? ar = arabic[key];
    final String? en = english[key];
    sheet.add(<String, Object?>{
      'key': key,
      'arabic': ar,
      'english': en,
      'screens': shownOn,
      'notes': _notesFor(arabic: ar, english: en, screens: shownOn),
    });
  }

  if (asJson) {
    final Map<String, Object?> out = <String, Object?>{
      'base': base,
      'added': sheet,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
    return 0;
  }

  _write(base: base, sheet: sheet, defined: arabic.length);
  return 0;
}

/// The keys the working tree has and the base did not, in order.
List<String> _keysAddedTo(Map<String, String> now, Map<String, String> was) {
  final List<String> added = <String>[];

  for (final String key in now.keys) {
    if (!was.containsKey(key)) {
      added.add(key);
    }
  }
  added.sort();

  return added;
}

/// The keys of one language file, as text. A value that is not a string is kept
/// as its JSON so that a malformed entry is shown rather than silently dropped.
Future<Map<String, String>> _read(String path) async {
  final File file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('MISSING language file: $path');
    exit(1);
  }

  return _asText(await file.readAsString(), path);
}

/// The same file as a git ref holds it, or null when that ref has no such file
/// (a branch that added the file, or a ref that is not fetched).
Future<Map<String, String>?> _readAt(String ref, String path) async {
  final List<String> command = <String>['show', '$ref:$path'];
  final ProcessResult shown = await Process.run('git', command);

  if (shown.exitCode != 0) {
    return null;
  }

  return _asText(shown.stdout as String, '$ref:$path');
}

Map<String, String> _asText(String source, String where) {
  final Object? decoded = jsonDecode(source);

  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('$where is not a JSON object.');
    exit(1);
  }

  final Map<String, String> text = <String, String>{};

  decoded.forEach((String key, Object? value) {
    text[key] = value is String ? value : jsonEncode(value);
  });

  return text;
}

/// Which files under lib/ show each of the given keys, by the one call that
/// shows one. A key resolved at runtime from a variable is past this, as it is
/// past the checker, and shows up as "used by no screen".
Future<Map<String, List<String>>> _screensShowing(List<String> keys) async {
  final Set<String> wanted = keys.toSet();
  final Map<String, Set<String>> found = <String, Set<String>>{};
  final Directory lib = Directory('lib');

  await for (final FileSystemEntity entity in lib.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    final String source = await entity.readAsString();

    for (final RegExpMatch match in _usage.allMatches(source)) {
      final String key = match.group(2)!;
      if (wanted.contains(key)) {
        (found[key] ??= <String>{}).add(entity.path);
      }
    }
  }

  final Map<String, List<String>> screens = <String, List<String>>{};

  found.forEach((String key, Set<String> files) {
    screens[key] = files.toList()..sort();
  });

  return screens;
}

/// What is wrong with one row of the sheet, in the words a reader needs. An
/// Arabic string equal to its English is called out because it is the shape a
/// placeholder takes: the key was added, the translation was not.
List<String> _notesFor({
  required String? arabic,
  required String? english,
  required List<String> screens,
}) {
  final List<String> notes = <String>[];
  final bool hasArabic = arabic != null && arabic.trim().isNotEmpty;
  final bool hasEnglish = english != null && english.trim().isNotEmpty;

  if (!hasArabic) {
    notes.add('no Arabic text');
  }
  if (english == null) {
    notes.add('not in en.json');
  } else if (!hasEnglish) {
    notes.add('no English text');
  }
  if (hasArabic && hasEnglish && arabic.trim() == english.trim()) {
    notes.add('Arabic is identical to the English: probably untranslated');
  }
  if (screens.isEmpty) {
    notes.add('used by no screen this tool can see');
  }

  return notes;
}

void _write({
  required String base,
  required List<Map<String, Object?>> sheet,
  required int defined,
}) {
  stdout.writeln('Keys this tree adds to $_arabic since $base');
  stdout.writeln(_rule);

  if (sheet.isEmpty) {
    stdout.writeln('None. $defined keys, every one already on $base.');

    return;
  }

  int flagged = 0;

  for (final Map<String, Object?> row in sheet) {
    final List<Object?> on = row['screens'] as List<Object?>;
    final List<Object?> notes = row['notes'] as List<Object?>;
    final String where = on.isEmpty ? '(none)' : on.join(', ');

    if (notes.isNotEmpty) {
      flagged++;
    }

    stdout.writeln('');
    stdout.writeln('key     : ${row['key']}');
    stdout.writeln('english : ${row['english'] ?? '(none)'}');
    stdout.writeln('arabic  : ${row['arabic'] ?? '(none)'}');
    stdout.writeln('screens : $where');

    for (final Object? note in notes) {
      stdout.writeln('NOTE    : $note');
    }
  }

  stdout.writeln('');
  stdout.writeln(_rule);
  stdout.writeln('${sheet.length} new key(s) for a native reader.');
  stdout.writeln('$flagged carry a note. $defined keys in $_arabic in all.');
}

String? _option(List<String> arguments, String name) {
  for (final String argument in arguments) {
    if (argument.startsWith('$name=')) {
      return argument.substring(name.length + 1);
    }
  }

  return null;
}
