import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The words of the platform admin shell, in both languages the app ships.
///
/// `tool/check_translations.dart` already fails the build when a key used in
/// code is missing from a language file or the two files drift apart. These
/// check what it cannot: that nothing is left in English in the Arabic file,
/// that no key of the shell is defined and never used, and that the words the
/// shell takes from other screens still say what the shell needs them to say.
void main() {
  final Map<String, dynamic> english =
      jsonDecode(File('assets/language/en.json').readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> arabic =
      jsonDecode(File('assets/language/ar.json').readAsStringSync()) as Map<String, dynamic>;

  final RegExp usage = RegExp(r'''getTranslated\(\s*['"]([A-Za-z0-9_ ]+?)['"]''');
  final Set<String> used = <String>{
    for (final File file in Directory('lib/features/platform_admin').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        ...usage.allMatches(file.readAsStringSync()).map((RegExpMatch match) => match.group(1)!),
  };
  final Set<String> own = used.where((String key) => key.startsWith('platform_admin_')).toSet();
  final RegExp arabicLetters = RegExp(r'[؀-ۿ]');

  test('the shell uses words, or every check below proves nothing', () {
    expect(used, isNotEmpty);
    expect(own, isNotEmpty);
  });

  group('every key the shell uses', () {
    test('is in the English file and in the Arabic file, with something in it', () {
      for (final String key in used) {
        expect(english[key], isA<String>().having((String text) => text.trim(), 'text', isNotEmpty),
            reason: 'en: $key');
        expect(arabic[key], isA<String>().having((String text) => text.trim(), 'text', isNotEmpty), reason: 'ar: $key');
      }
    });
  });

  group('the keys of the shell', () {
    test('are all used: none is defined and left behind', () {
      final Set<String> defined = english.keys.where((String key) => key.startsWith('platform_admin_')).toSet();

      expect(defined.difference(own), isEmpty);
    });

    test('are the same in both languages', () {
      expect(arabic.keys.where((String key) => key.startsWith('platform_admin_')).toSet(),
          english.keys.where((String key) => key.startsWith('platform_admin_')).toSet());
    });

    test('are in Arabic in the Arabic file and in English in the English file', () {
      for (final String key in own) {
        expect(arabicLetters.hasMatch(arabic[key] as String), isTrue, reason: 'ar: $key is not Arabic: ${arabic[key]}');
        expect(arabicLetters.hasMatch(english[key] as String), isFalse,
            reason: 'en: $key has Arabic in it: ${english[key]}');
      }
    });

    test('say something different in the two languages, so that no key was copied across', () {
      for (final String key in own) {
        expect(arabic[key], isNot(english[key]), reason: key);
      }
    });

    test('are written plainly: no technical word and no leftover placeholder', () {
      for (final String key in own) {
        for (final String language in <String>[english[key] as String, arabic[key] as String]) {
          expect(
              language,
              isNot(matches(
                  RegExp(r'[{}%$]|\bnull\b|\bundefined\b|\bTODO\b|\bAPI\b|\bJSON\b|\btoken\b', caseSensitive: false))),
              reason: '$key: $language');
        }
      }
    });
  });
}
