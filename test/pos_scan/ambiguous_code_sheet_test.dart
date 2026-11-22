import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syriacosmeticsmanger/features/pos/domain/models/product_scan_refusal_model.dart';
import 'package:syriacosmeticsmanger/features/pos/widgets/ambiguous_code_sheet_widget.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

import 'support/harness.dart';

/// The sheet a seller sees when the code they scanned belongs to more than one of their products.
const ScanCandidateModel _serumSaudi = ScanCandidateModel(id: 1, name: 'Rose Serum 30 ml', country: 'SA');
const ScanCandidateModel _serumKuwait = ScanCandidateModel(id: 2, name: 'Rose Serum 50 ml', country: 'KW');
const ScanCandidateModel _serumSaudiTwin = ScanCandidateModel(id: 3, name: 'Rose Serum 30 ml (new box)', country: 'SA');

const List<ScanCandidateModel> _sameCountry = <ScanCandidateModel>[_serumSaudi, _serumSaudiTwin];
const List<ScanCandidateModel> _differentCountries = <ScanCandidateModel>[_serumSaudi, _serumKuwait];

const String _enTitle = 'Several products share this code';
const String _enChooseCountry = 'The same code is used in different countries. Tap the product you want to add.';
const String _enOpenListText = 'A scan cannot choose between them. Open your product list and pick the right product.';
const String _enOpenListButton = 'Open product list';
const String _arTitle = 'هذا الرمز مشترك بين عدة منتجات';
const String _arOpenListButton = 'فتح قائمة المنتجات';

class _Taps {
  final List<String> chosenCountries = <String>[];
  int productListOpened = 0;
}

/// Opens the sheet the way the scan does, from a screen of the real app, and hands back what the seller's taps did.
Future<_Taps> _open(
  WidgetTester tester, {
  required List<ScanCandidateModel> candidates,
  required bool canChooseCountry,
  Locale locale = PosScanHarness.english,
  double textScale = 1.0,
  bool darkTheme = false,
  Size screen = PosScanHarness.phone,
}) async {
  PosScanHarness.useScreen(tester, screen);
  final _Taps taps = _Taps();

  await tester.pumpWidget(await PosScanHarness.app(
    tester,
    locale: locale,
    textScale: textScale,
    darkTheme: darkTheme,
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAmbiguousCodeSheet(
              context: context,
              candidates: candidates,
              canChooseCountry: canChooseCountry,
              onCountryChosen: taps.chosenCountries.add,
              onOpenProductList: () => taps.productListOpened++,
            ),
            child: const Text('scan'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('scan'));
  await tester.pumpAndSettle();

  return taps;
}

Finder get _sheet => find.byType(AmbiguousCodeSheetWidget);

/// The button of the sheet, not the one of the screen underneath it.
Finder get _sheetButton => find.descendant(of: _sheet, matching: find.byType(ElevatedButton));

/// The rows of the sheet that answer to a tap.
Finder get _tappableRows => find.descendant(of: _sheet, matching: find.byType(InkWell));

/// The surface of the row that holds [productName]: the one with the rounded corners of a row, not the sheet's own.
Material _rowSurface(WidgetTester tester, String productName) {
  final Finder surface = find.ancestor(
    of: find.text(productName),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Material &&
          widget.shape is RoundedRectangleBorder &&
          (widget.shape! as RoundedRectangleBorder).borderRadius == BorderRadius.circular(Dimensions.radiusDefault),
    ),
  );

  return tester.widget<Material>(surface);
}

/// How well [text] reads on [background], as the ratio of the two luminances: 4.5 is what WCAG asks of text this size.
double _contrast(Color text, Color background) {
  final double textLuminance = text.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();

  return (math.max(textLuminance, backgroundLuminance) + 0.05) / (math.min(textLuminance, backgroundLuminance) + 0.05);
}

void main() {
  group('several products share the code inside one country', () {
    testWidgets('says so plainly, names the products with their country, and offers the product list',
        (WidgetTester tester) async {
      await _open(tester, candidates: _sameCountry, canChooseCountry: false);

      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text(_enOpenListText), findsOneWidget);
      expect(find.text('Rose Serum 30 ml'), findsOneWidget);
      expect(find.text('Rose Serum 30 ml (new box)'), findsOneWidget);
      expect(find.text('Saudi Arabia'), findsNWidgets(2));
      expect(find.text(_enOpenListButton), findsOneWidget);
      expect(find.text(_enChooseCountry), findsNothing);
    });

    testWidgets('does not turn the products into choices: no row answers a tap, none is marked as one',
        (WidgetTester tester) async {
      final _Taps taps = await _open(tester, candidates: _sameCountry, canChooseCountry: false);

      await tester.tap(find.text('Rose Serum 30 ml'));
      await tester.pumpAndSettle();

      expect(_sheet, findsOneWidget);
      expect(taps.chosenCountries, isEmpty);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('the button closes the sheet and opens the product list once', (WidgetTester tester) async {
      final _Taps taps = await _open(tester, candidates: _sameCountry, canChooseCountry: false);

      await tester.tap(find.text(_enOpenListButton));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(taps.productListOpened, 1);
      expect(taps.chosenCountries, isEmpty);
    });

    testWidgets('a refusal with nobody to list still explains itself and still offers the product list',
        (WidgetTester tester) async {
      final _Taps taps = await _open(tester, candidates: const <ScanCandidateModel>[], canChooseCountry: false);

      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text(_enOpenListText), findsOneWidget);

      await tester.tap(find.text(_enOpenListButton));
      await tester.pumpAndSettle();

      expect(taps.productListOpened, 1);
    });

    testWidgets('is the same sheet when two countries are listed but the seller already chose one',
        (WidgetTester tester) async {
      await _open(tester, candidates: _differentCountries, canChooseCountry: false);

      expect(find.text(_enOpenListButton), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('the products sit in different countries', () {
    testWidgets('asks the seller to choose, with every product a choice and no product list button',
        (WidgetTester tester) async {
      await _open(tester, candidates: _differentCountries, canChooseCountry: true);

      expect(find.text(_enTitle), findsOneWidget);
      expect(find.text(_enChooseCountry), findsOneWidget);
      expect(find.text('Rose Serum 30 ml'), findsOneWidget);
      expect(find.text('Saudi Arabia'), findsOneWidget);
      expect(find.text('Rose Serum 50 ml'), findsOneWidget);
      expect(find.text('Kuwait'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(find.text(_enOpenListButton), findsNothing);
      expect(find.text(_enOpenListText), findsNothing);
    });

    testWidgets('a tap on a product closes the sheet and asks again for that product\'s country, once',
        (WidgetTester tester) async {
      final _Taps taps = await _open(tester, candidates: _differentCountries, canChooseCountry: true);

      await tester.tap(find.text('Rose Serum 50 ml'));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(taps.chosenCountries, <String>['KW']);
      expect(taps.productListOpened, 0);
    });

    testWidgets('asks for the country in upper case whatever way the server spelled it', (WidgetTester tester) async {
      final _Taps taps = await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          ScanCandidateModel(id: 1, name: 'First', country: ' ae '),
          ScanCandidateModel(id: 2, name: 'Second', country: 'qa'),
        ],
        canChooseCountry: true,
      );

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();

      expect(taps.chosenCountries, <String>['AE']);
      expect(find.text('UAE'), findsNothing, reason: 'the sheet is closed');
    });

    testWidgets('a product whose country the app cannot name is shown as the server wrote it and cannot be chosen',
        (WidgetTester tester) async {
      final _Taps taps = await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          _serumSaudi,
          _serumKuwait,
          ScanCandidateModel(id: 9, name: 'Strange Serum', country: 'XX'),
          ScanCandidateModel(id: 10, name: 'Homeless Serum', country: null),
        ],
        canChooseCountry: true,
      );

      expect(find.text('XX'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

      await tester.tap(find.text('Strange Serum'));
      await tester.tap(find.text('Homeless Serum'));
      await tester.pumpAndSettle();

      expect(_sheet, findsOneWidget);
      expect(taps.chosenCountries, isEmpty);
    });

    testWidgets('names all six markets in English', (WidgetTester tester) async {
      await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          ScanCandidateModel(id: 1, name: 'One', country: 'SA'),
          ScanCandidateModel(id: 2, name: 'Two', country: 'AE'),
          ScanCandidateModel(id: 3, name: 'Three', country: 'KW'),
          ScanCandidateModel(id: 4, name: 'Four', country: 'QA'),
          ScanCandidateModel(id: 5, name: 'Five', country: 'BH'),
          ScanCandidateModel(id: 6, name: 'Six', country: 'OM'),
        ],
        canChooseCountry: true,
        screen: PosScanHarness.phone,
      );

      for (final String name in <String>['Saudi Arabia', 'UAE', 'Kuwait', 'Qatar', 'Bahrain', 'Oman']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });
  });

  group('the size of the sheet', () {
    testWidgets('follows the list: two products make a short sheet, not a screen', (WidgetTester tester) async {
      await _open(tester, candidates: _sameCountry, canChooseCountry: false);

      expect(tester.getSize(_sheet).height, lessThan(PosScanHarness.phone.height * 0.6));
    });

    testWidgets('a short sheet sits at the bottom of the screen, as a sheet does', (WidgetTester tester) async {
      await _open(tester, candidates: _differentCountries, canChooseCountry: true);

      expect(tester.getRect(_sheet).bottom, PosScanHarness.phone.height);
    });
  });

  group('how it looks', () {
    testWidgets('a product that can be chosen is outlined, one that cannot is flat and tinted',
        (WidgetTester tester) async {
      await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          _serumSaudi,
          _serumKuwait,
          ScanCandidateModel(id: 9, name: 'Strange Serum', country: 'XX'),
        ],
        canChooseCountry: true,
      );
      final Color card = Theme.of(tester.element(_sheet)).cardColor;

      final Material choice = _rowSurface(tester, 'Rose Serum 30 ml');
      final Material notAChoice = _rowSurface(tester, 'Strange Serum');

      expect((choice.shape! as RoundedRectangleBorder).side, isNot(BorderSide.none));
      expect(choice.color, card);
      expect((notAChoice.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(notAChoice.color, isNot(card));
    });

    for (final bool darkTheme in <bool>[false, true]) {
      testWidgets(
          'every text keeps a contrast of 4.5 to 1 on the card and on a flat row, ${darkTheme ? 'dark' : 'light'} theme',
          (WidgetTester tester) async {
        await _open(
          tester,
          candidates: const <ScanCandidateModel>[
            _serumSaudi,
            _serumKuwait,
            ScanCandidateModel(id: 9, name: 'Strange Serum', country: 'XX'),
          ],
          canChooseCountry: true,
          darkTheme: darkTheme,
        );
        final ThemeData theme = Theme.of(tester.element(_sheet));
        final Color card = theme.cardColor;
        final Color flatRow = Color.alphaBlend(theme.hintColor.withValues(alpha: 0.08), card);
        final Finder texts = find.descendant(
          of: find.descendant(of: _sheet, matching: find.byType(SingleChildScrollView)),
          matching: find.byType(Text),
        );

        expect(texts, findsWidgets);
        for (final Text text in tester.widgetList<Text>(texts)) {
          final Color color = text.style!.color!;

          expect(_contrast(color, card), greaterThanOrEqualTo(4.5), reason: '"${text.data}" on the card');
          expect(_contrast(color, flatRow), greaterThanOrEqualTo(4.5), reason: '"${text.data}" on a flat row');
        }
      });
    }
  });

  group('a product that has no name', () {
    testWidgets('is shown by its number, or by a dash when it has none either', (WidgetTester tester) async {
      await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          ScanCandidateModel(id: 12, name: '', country: 'SA'),
          ScanCandidateModel(id: null, name: '', country: 'SA'),
        ],
        canChooseCountry: false,
      );

      expect(find.text('#12'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
    });
  });

  group('in Arabic', () {
    testWidgets('reads in Arabic, from the right, with the chevron pointing the way the language reads',
        (WidgetTester tester) async {
      await _open(
        tester,
        candidates: _differentCountries,
        canChooseCountry: true,
        locale: PosScanHarness.arabic,
        screen: PosScanHarness.narrowPhone,
      );

      expect(find.text(_arTitle), findsOneWidget);
      expect(find.text('السعودية'), findsOneWidget);
      expect(find.text('الكويت'), findsOneWidget);
      expect(Directionality.of(tester.element(_sheet)), TextDirection.rtl);

      // The title starts at the right edge of the sheet's padding, the first product's chevron at the left edge of its row.
      expect(tester.getTopRight(find.text(_arTitle)).dx, closeTo(320 - 20, 0.5));
      final Rect row =
          tester.getRect(find.ancestor(of: find.text('Rose Serum 30 ml'), matching: find.byType(InkWell)).first);
      final Rect chevron = tester.getRect(find.byIcon(Icons.chevron_right).first);
      expect(chevron.center.dx, lessThan(row.center.dx));
      final Icon chevronIcon = tester.widget<Icon>(find.byIcon(Icons.chevron_right).first);
      expect(chevronIcon.icon!.matchTextDirection, isTrue);
    });

    testWidgets('the same sheet in English starts at the left edge', (WidgetTester tester) async {
      await _open(tester, candidates: _differentCountries, canChooseCountry: true, screen: PosScanHarness.narrowPhone);

      expect(tester.getTopLeft(find.text(_enTitle)).dx, closeTo(20, 0.5));
    });

    testWidgets('offers the product list in Arabic', (WidgetTester tester) async {
      final _Taps taps = await _open(
        tester,
        candidates: _sameCountry,
        canChooseCountry: false,
        locale: PosScanHarness.arabic,
      );

      await tester.tap(find.text(_arOpenListButton));
      await tester.pumpAndSettle();

      expect(taps.productListOpened, 1);
    });

    testWidgets('names all six markets in Arabic', (WidgetTester tester) async {
      await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          ScanCandidateModel(id: 1, name: 'One', country: 'SA'),
          ScanCandidateModel(id: 2, name: 'Two', country: 'AE'),
          ScanCandidateModel(id: 3, name: 'Three', country: 'KW'),
          ScanCandidateModel(id: 4, name: 'Four', country: 'QA'),
          ScanCandidateModel(id: 5, name: 'Five', country: 'BH'),
          ScanCandidateModel(id: 6, name: 'Six', country: 'OM'),
        ],
        canChooseCountry: true,
        locale: PosScanHarness.arabic,
      );

      for (final String name in <String>['السعودية', 'الإمارات', 'الكويت', 'قطر', 'البحرين', 'عُمان']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });
  });

  group('layout', () {
    // Every third product has no country, so some rows are one line high and rely on their minimum height.
    final List<ScanCandidateModel> manyProducts = <ScanCandidateModel>[
      for (int index = 1; index <= 50; index++)
        ScanCandidateModel(
          id: index,
          name: index % 3 == 0
              ? 'Short $index'
              : 'Rose Serum with a very long name that needs more than one line to be read, number $index',
          country: index % 3 == 0 ? null : (index.isEven ? 'SA' : 'KW'),
        ),
    ];

    for (final Locale locale in <Locale>[PosScanHarness.english, PosScanHarness.arabic]) {
      for (final bool darkTheme in <bool>[false, true]) {
        for (final ({String label, Size screen, double scale}) setting in <({String label, Size screen, double scale})>[
          (label: '320x640 at 2x text', screen: PosScanHarness.narrowPhone, scale: 2.0),
          (label: '390x844 at 1x text', screen: PosScanHarness.phone, scale: 1.0),
        ]) {
          final String where = '${locale.languageCode}, ${darkTheme ? 'dark' : 'light'}, ${setting.label}';

          testWidgets('holds together with the product list button: $where', (WidgetTester tester) async {
            await _open(
              tester,
              candidates: manyProducts,
              canChooseCountry: false,
              locale: locale,
              darkTheme: darkTheme,
              screen: setting.screen,
              textScale: setting.scale,
            );

            expect(tester.takeException(), isNull);
            final Rect sheet = tester.getRect(_sheet);
            expect(sheet.height, lessThanOrEqualTo(setting.screen.height * 0.85 + 0.5));
            expect(sheet.left, greaterThanOrEqualTo(0));
            expect(sheet.right, lessThanOrEqualTo(setting.screen.width));

            final Rect buttonRect = tester.getRect(_sheetButton);
            expect(buttonRect.bottom, lessThanOrEqualTo(setting.screen.height),
                reason: 'the button stays on the screen');
            expect(buttonRect.height, greaterThanOrEqualTo(48));
            expect(buttonRect.left, greaterThanOrEqualTo(sheet.left));
            expect(buttonRect.right, lessThanOrEqualTo(sheet.right));
          });

          testWidgets('holds together when the seller has to choose: $where', (WidgetTester tester) async {
            await _open(
              tester,
              candidates: manyProducts,
              canChooseCountry: true,
              locale: locale,
              darkTheme: darkTheme,
              screen: setting.screen,
              textScale: setting.scale,
            );

            expect(tester.takeException(), isNull);
            final Rect sheet = tester.getRect(_sheet);
            expect(sheet.height, lessThanOrEqualTo(setting.screen.height * 0.85 + 0.5));

            // Every row that is on the screen is a target a thumb can hit.
            for (final Element row in _tappableRows.evaluate()) {
              final Rect rect = tester.getRect(find.byWidget(row.widget));
              expect(rect.height, greaterThanOrEqualTo(48), reason: where);
              expect(rect.width, lessThanOrEqualTo(setting.screen.width), reason: where);
            }
          });
        }
      }
    }

    testWidgets('the list scrolls by hand to its last product at 320x640 and 2x text, and a tap there still works',
        (WidgetTester tester) async {
      final _Taps taps = await _open(
        tester,
        candidates: <ScanCandidateModel>[
          for (int index = 1; index <= 30; index++)
            ScanCandidateModel(id: index, name: 'Product $index', country: index.isEven ? 'SA' : 'KW'),
        ],
        canChooseCountry: true,
        screen: PosScanHarness.narrowPhone,
        textScale: 2.0,
      );

      final Finder lastProduct = find.text('Product 30');
      expect(lastProduct.hitTestable(), findsNothing, reason: 'it starts below the fold');

      // Real drags only: dragUntilVisible ends by scrolling the item into view itself, which would hide a list that cannot be scrolled.
      for (int drag = 0; drag < 60 && lastProduct.hitTestable().evaluate().isEmpty; drag++) {
        await tester.drag(
            find.descendant(of: _sheet, matching: find.byType(SingleChildScrollView)), const Offset(0, -200));
        await tester.pump();
      }

      expect(lastProduct.hitTestable(), findsOneWidget);
      await tester.tap(lastProduct);
      await tester.pumpAndSettle();

      expect(taps.chosenCountries, <String>['SA']);
    });

    testWidgets('a long product name is cut at two lines, so one product cannot fill the sheet',
        (WidgetTester tester) async {
      await _open(
        tester,
        candidates: const <ScanCandidateModel>[
          ScanCandidateModel(
              id: 1,
              name: 'A product name that is long enough to need a good many lines on the narrowest phone, '
                  'and then some more words, and then some more, and still more words to read',
              country: 'SA'),
        ],
        canChooseCountry: false,
        screen: PosScanHarness.narrowPhone,
        textScale: 2.0,
      );

      final Text name = tester.widget<Text>(find.textContaining('A product name that is long enough'));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long title and explanation wrap instead of overflowing, in Arabic at 2x text on the narrowest phone',
        (WidgetTester tester) async {
      await _open(
        tester,
        candidates: _sameCountry,
        canChooseCountry: false,
        locale: PosScanHarness.arabic,
        screen: PosScanHarness.narrowPhone,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(_sheetButton).bottom, lessThanOrEqualTo(640));
    });
  });

  group('for a person who cannot see it', () {
    testWidgets('the title is announced as a heading and the tappable products as buttons',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _open(tester, candidates: _differentCountries, canChooseCountry: true);

      expect(tester.getSemantics(find.text(_enTitle)),
          matchesSemantics(label: _enTitle, isHeader: true, textDirection: TextDirection.ltr));
      expect(tester.getSemantics(find.text('Rose Serum 50 ml')),
          isSemantics(isButton: true, hasTapAction: true, label: 'Rose Serum 50 ml\nKuwait'));

      semantics.dispose();
    });

    testWidgets('a product that cannot be chosen has no tap action', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _open(tester, candidates: _sameCountry, canChooseCountry: false);

      expect(tester.getSemantics(find.text('Rose Serum 30 ml')), isSemantics(isButton: false, hasTapAction: false));

      semantics.dispose();
    });
  });
}
