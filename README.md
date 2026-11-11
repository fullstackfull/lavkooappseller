# Siller Center — seller app

Flutter vendor app for the Siller Center cosmetics store (a customised fork of
the Sixvalley seller app).

## Getting started

```bash
flutter pub get
flutter run
```

## Toolchain

- Flutter **3.47.0** stable (Dart 3.11), pinned in CI. The themes use
  `CardThemeData` and `DialogThemeData`, so Flutter 3.27 is the practical
  minimum.
- Android Gradle Plugin **8.13.2**, Kotlin **2.2.21**, Gradle 8.14.3, Java 17+.
  Flutter enforces a minimum AGP and Kotlin version and raises it over time, so
  bump `android/settings.gradle.kts` together with the pinned Flutter version
  in CI — and run `flutter build apk --debug` before pushing that bump.
- `compileSdk`/`targetSdk` come from the Flutter plugin (36). Library
  subprojects are pinned to the same level in `android/build.gradle.kts`
  because some transitive plugins still hardcode an older one.
- iOS: deployment target 15.0 (required by the Firebase SDK).

## Checks

Run these before pushing; CI (`.github/workflows/ci.yml`) runs the same set.

```bash
flutter analyze --no-fatal-infos       # must exit 0
dart run tool/check_translations.dart  # en.json / ar.json key parity
flutter test
```

Use `flutter analyze`, not `dart analyze`: only the former treats warnings as
fatal, which is what CI enforces. `dart analyze` will pass on a tree that fails
the build.

## Languages

English and Arabic, in `assets/language/`. `getTranslated()` falls back to the
English value when a key is missing from the active language, and to the key
itself only if it is absent everywhere — the translation check above keeps that
from happening.

## Release

`MIGRATION.md` has the release checklist: signing keystore, application ID, and
Firebase project. All three need doing before the first store upload.
