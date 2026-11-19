import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/utill/shop_image_rules.dart';

/// The two forms that ask a seller for shop images, and the screen that refuses a registration without one.
const String _registrationFormPath = 'lib/features/auth/widgets/info_field_widget.dart';
const String _registrationScreenPath = 'lib/features/auth/screens/registration_screen.dart';
const String _shopFormPath = 'lib/features/shop/screens/shop_update_screen.dart';

/// The only two files of the app that may name the one global active theme: the table that holds the image rules, and
/// the model the config is parsed into.
const List<String> _mayNameTheGlobalTheme = <String>[
  'lib/utill/shop_image_rules.dart',
  'lib/features/splash/domain/models/config_model.dart',
];

/// Whether a registration asks a seller for the secondary banner, as both halves of that rule read it: the form that
/// offers the uploader and the screen that refuses a registration without the image. One string, so a test cannot pin
/// one half to an answer the other half does not read.
const String _registrationSecondaryBannerAnswer =
    'ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner)'
    '.isAskedOf(Provider.of<SplashController>(context,listen: false).configModel!)';

/// Each slot of a form, as the block of the form that asks for it: from the label of the slot, or the condition that
/// offers it, to the start of the next slot.
const Map<ShopImageSlot, List<String>> _registrationBlocks = <ShopImageSlot, List<String>>{
  ShopImageSlot.profileImage: <String>["getTranslated('store_logo'", "getTranslated('store_image'"],
  ShopImageSlot.logo: <String>["getTranslated('store_image'", "getTranslated('store_banner'"],
  ShopImageSlot.banner: <String>[
    "getTranslated('store_banner'",
    'ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner)',
  ],
  ShopImageSlot.secondaryBanner: <String>['ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner)', ''],
};

const Map<ShopImageSlot, List<String>> _shopFormBlocks = <ShopImageSlot, List<String>>{
  ShopImageSlot.logo: <String>["getTranslated('shop_logo'", "getTranslated('shop_cover'"],
  ShopImageSlot.banner: <String>[
    "getTranslated('shop_cover'",
    'if(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner)',
  ],
  ShopImageSlot.secondaryBanner: <String>[
    'if(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner)',
    'if(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner)',
  ],
  ShopImageSlot.offerBanner: <String>['if(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner)', ''],
};

/// A form of the table asked for one slot, as the app writes it: the form it asks and the slot it asks for.
final RegExp _slotAskedOfAForm = RegExp(r'ShopImageRules\.(inRegistration|inShopUpdate)\(ShopImageSlot\.(\w+)\)');

/// A read of the one global active theme: the field of the config, the key it is parsed from, or a storefront theme
/// named in the code. An import, export or part of a Dart file is not one, whatever the file is called.
final RegExp _globalTheme = RegExp(r'''\bactiveTheme\b|['"]active_theme['"]|['"]theme_aster['"]|['"]theme_fashion['"]''');

/// The ratio and the size texts the two seller forms stated before the rules moved into the table. The product forms
/// state image rules of their own, which are a different axis and are not scanned here.
final RegExp _imageRuleText = RegExp(
    r'''['"](?:image_ratio3?|ratio_1_1|ratio_4_1|image_size|image_size_2_mb|jpg_png_less_then_1_mb|\(3:1\)|\(7:1\))['"]''');

String _read(String path) => File(path).readAsStringSync();

/// Every Dart file of the app.
Iterable<File> _dartFilesUnderLib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'));

/// [text] with its whitespace collapsed and a line break inside a method chain closed up, so that a condition reads
/// the same however the file wraps it.
String _squeezed(String text) => text.replaceAll(RegExp(r'\s+'), ' ').replaceAll(' .', '.').trim();

/// The lines of [source] that match [pattern], as `line: text`.
List<String> _linesMatching(String source, RegExp pattern) {
  final List<String> lines = source.split('\n');
  final List<String> found = <String>[];

  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index].trim();
    final bool isDirective = line.startsWith('import ') || line.startsWith('export ') || line.startsWith('part ');

    if (!isDirective && pattern.hasMatch(line)) {
      found.add('${index + 1}: $line');
    }
  }

  return found;
}

List<String> globalThemeLinesOf(String source) => _linesMatching(source, _globalTheme);

List<String> imageRuleTextLinesOf(String source) => _linesMatching(source, _imageRuleText);

/// The part of [source] that asks for one slot: from [anchors] first to [anchors] last, the last being the end of the
/// file when it is empty.
String _blockOf(String source, List<String> anchors) {
  final int start = source.indexOf(anchors.first);
  expect(start, isNonNegative, reason: 'the block does not start: ${anchors.first}');

  if (anchors.last.isEmpty) {
    return source.substring(start);
  }

  final int end = source.indexOf(anchors.last, start + anchors.first.length);
  expect(end, greaterThan(start), reason: 'the block does not end: ${anchors.last}');
  return source.substring(start, end);
}

/// How a form reads the ratio and the size of [slot] from the table.
List<String> _ruleCallsOf(String form, ShopImageSlot slot, ShopImageRule rule) => <String>[
      if (rule.ratioLabelKey != null) 'ShopImageRules.$form(ShopImageSlot.${slot.name}).ratioLabelKey',
      if (rule.ratioLabel != null) 'ShopImageRules.$form(ShopImageSlot.${slot.name}).ratioLabel!',
      'ShopImageRules.$form(ShopImageSlot.${slot.name}).sizeLabelKey',
    ];

void _expectEachSlotReadsItsOwnRule(
  String path,
  String form,
  Map<ShopImageSlot, List<String>> blocks,
  ShopImageRule Function(ShopImageSlot) ruleOf,
) {
  final String source = _read(path);
  final List<String> everyCall = <String>[
    for (final ShopImageSlot slot in blocks.keys) ..._ruleCallsOf(form, slot, ruleOf(slot)),
  ];

  for (final MapEntry<ShopImageSlot, List<String>> block in blocks.entries) {
    final String asked = _blockOf(source, block.value);
    final List<String> own = _ruleCallsOf(form, block.key, ruleOf(block.key));

    for (final String call in own) {
      expect(asked, contains(call), reason: '${block.key} does not read $call');
    }
    for (final String call in everyCall.where((String call) => !own.contains(call))) {
      expect(asked, isNot(contains(call)), reason: '${block.key} also reads $call');
    }
  }
}

/// Whether [source] opens an expression with [condition], spacing aside: the condition has to come first in it, after
/// a character no expression continues over. A `!`, a `true ||` or a flag `&&` put in front of a condition flips who is
/// asked for an image, and a check that looks for the condition anywhere in the file cannot see one.
bool _opensAnExpressionWith(String source, String condition) =>
    RegExp('[,;(\\[{] ?${RegExp.escape(condition)}').hasMatch(_squeezed(source));

/// The condition a form writes, and writes first in its expression. The file is not the reason given, because a form is
/// thousands of lines long and the condition is what a reader needs.
void _expectCondition(String path, String condition) {
  expect(_opensAnExpressionWith(_read(path), condition), isTrue,
      reason: '$path does not open an expression with: $condition');
}

void main() {
  group('the two forms read every image rule from the table', () {
    test('each slot of registration reads the rule of its own slot and of no other', () {
      _expectEachSlotReadsItsOwnRule(
        _registrationFormPath,
        'inRegistration',
        _registrationBlocks,
        ShopImageRules.inRegistration,
      );
    });

    test('each slot of the shop form reads the rule of its own slot and of no other', () {
      _expectEachSlotReadsItsOwnRule(
        _shopFormPath,
        'inShopUpdate',
        _shopFormBlocks,
        ShopImageRules.inShopUpdate,
      );
    });

    test('the two forms write no ratio and no size of their own any more', () {
      for (final String path in <String>[_registrationFormPath, _registrationScreenPath, _shopFormPath]) {
        final String source = _read(path);

        expect(source, contains('ShopImageRules.'), reason: '$path does not read the table at all');
        expect(imageRuleTextLinesOf(source), isEmpty,
            reason: '$path states an image rule of its own:\n${imageRuleTextLinesOf(source).join('\n')}');
      }
    });
  });

  group('the storefronts each form asks a slot on', () {
    test('the shop form asks the table whether to offer its two extra banners', () {
      for (final String condition in <String>[
        'if(ShopImageRules.inShopUpdate(ShopImageSlot.secondaryBanner)'
            '.isAskedOf(Provider.of<SplashController>(context, listen: false).configModel))',
        'if(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner)'
            '.isAskedOf(Provider.of<SplashController>(context, listen: false).configModel))',
      ]) {
        _expectCondition(_shopFormPath, condition);
      }
    });

    test('registration asks the table whether to offer its secondary banner', () {
      _expectCondition(_registrationFormPath, '$_registrationSecondaryBannerAnswer ?');
    });

    test('registration refuses a registration without the secondary banner by the same answer', () {
      _expectCondition(
        _registrationScreenPath,
        'authController.secondaryBanner == null && $_registrationSecondaryBannerAnswer',
      );
    });

    test('the condition check sees what is put in front of a condition (it guards the guard)', () {
      const String condition = 'ShopImageRules.inRegistration(ShopImageSlot.secondaryBanner).isAskedOf(config) ?';

      expect(_opensAnExpressionWith('children: [ $condition offered : hidden ],', condition), isTrue);
      expect(_opensAnExpressionWith('children: [ !$condition offered : hidden ],', condition), isFalse);
      expect(_opensAnExpressionWith('children: [ true || $condition offered : hidden ],', condition), isFalse);
      expect(_opensAnExpressionWith('children: [ showAll && $condition offered : hidden ],', condition), isFalse);
    });
  });

  group('no file of the app asks a form for an image that form has no rule for', () {
    test('every form and slot a file under lib names is a pair the tables hold', () {
      final Map<String, Iterable<ShopImageSlot>> slotsOfForm = <String, Iterable<ShopImageSlot>>{
        'inRegistration': ShopImageRules.registrationSlots,
        'inShopUpdate': ShopImageRules.shopUpdateSlots,
      };
      final Set<String> pairsHeld = <String>{
        for (final MapEntry<String, Iterable<ShopImageSlot>> form in slotsOfForm.entries)
          for (final ShopImageSlot slot in form.value) '${form.key}(${slot.name})',
      };
      final Set<String> pairsAsked = <String>{};
      final List<String> offenders = <String>[];

      for (final File file in _dartFilesUnderLib()) {
        for (final RegExpMatch asked in _slotAskedOfAForm.allMatches(file.readAsStringSync())) {
          final String pair = '${asked.group(1)}(${asked.group(2)})';
          pairsAsked.add(pair);

          if (!pairsHeld.contains(pair)) {
            offenders.add('${file.path}: $pair');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'the two tables are partial: registration asks a seller for no offer banner and the shop form for no '
            'profile image. A form asked for a slot it has no rule for answers nothing, so the form throws where it '
            'builds. Offending calls:\n${offenders.join('\n')}',
      );
      expect(pairsAsked, pairsHeld,
          reason: 'the scan did not reach every rule the tables hold, so it proves less than it reads');
    });
  });

  group('no file of the app decides an image rule from the one global theme', () {
    test('the table and the config model are the only files under lib that name it', () {
      final List<String> offenders = <String>[];
      final List<String> allowed = <String>[];

      for (final File file in _dartFilesUnderLib()) {
        final List<String> found = globalThemeLinesOf(file.readAsStringSync());
        if (found.isEmpty) {
          continue;
        }
        if (_mayNameTheGlobalTheme.contains(file.path)) {
          allowed.add(file.path);
          continue;
        }
        for (final String line in found) {
          offenders.add('${file.path}:$line');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'a theme served per country (GCC-07) stops meaning what one global active_theme means, so a screen that '
            'reads it picks another market\'s image rule. Offending lines:\n${offenders.join('\n')}',
      );
      expect(allowed..sort(), _mayNameTheGlobalTheme.toList()..sort(),
          reason: 'the scan did not reach the two files that do name it, so it proves nothing');
    });

    test('the scan sees a theme read when one is written (it guards the guard)', () {
      const List<String> reads = <String>[
        'if (configModel?.activeTheme == "theme_aster")',
        "final bool isAster = config.activeTheme == 'theme_aster';",
        "activeTheme = json['active_theme'];",
        'Provider.of<SplashController>(context,listen: false).configModel!.activeTheme != "default"',
        "child: theme == 'theme_fashion' ? const OfferBanner() : const SizedBox(),",
      ];

      for (final String line in reads) {
        expect(globalThemeLinesOf(line), hasLength(1), reason: line);
      }
    });

    test('the scan leaves the app\'s own colour theme, and names that only look like it, alone', () {
      const List<String> notReads = <String>[
        "import 'package:syriacosmeticsmanger/theme/controllers/theme_controller.dart';",
        'final controller = Provider.of<ThemeController>(context);',
        'color: Theme.of(context).primaryColor,',
        "static const String activeThemeless = 'x';",
        "if (name == 'theme_asterisk') {",
        "final String text = 'the theme of the shop';",
      ];

      for (final String line in notReads) {
        expect(globalThemeLinesOf(line), isEmpty, reason: line);
      }
    });

    test('the rule scan sees a ratio or a size when one is written', () {
      const List<String> rules = <String>[
        "Text('(3:1)', style: robotoRegular),",
        "Text('(7:1)', style: robotoRegular),",
        "Text(getTranslated('image_size_2_mb', context)!),",
        "TextSpan(text: getTranslated('ratio_4_1', context) ?? ''),",
        "TextSpan(text: getTranslated('jpg_png_less_then_1_mb', context) ?? ''),",
        "Text(getTranslated('image_ratio3', context)!),",
        "Text(getTranslated('image_size', context)!),",
      ];

      for (final String line in rules) {
        expect(imageRuleTextLinesOf(line), hasLength(1), reason: line);
      }
    });

    test('the rule scan leaves the table\'s own reads, and text that only looks like a rule, alone', () {
      const List<String> notRules = <String>[
        'Text(getTranslated(ShopImageRules.inRegistration(ShopImageSlot.banner).ratioLabelKey, context)!),',
        'Text(ShopImageRules.inShopUpdate(ShopImageSlot.offerBanner).ratioLabel!),',
        "import 'package:syriacosmeticsmanger/helper/image_size_checker.dart';",
        "Text(getTranslated('image_size_of_the_product', context)!),",
        "Text('3:1'),",
        'final double ratio = 3 / 1;',
      ];

      for (final String line in notRules) {
        expect(imageRuleTextLinesOf(line), isEmpty, reason: line);
      }
    });
  });
}
