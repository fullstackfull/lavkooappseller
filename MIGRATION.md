# Siller Center — release checklist and handover notes

This file covers the three things the code cannot do for itself, plus what was
deliberately left alone and why.

---

## 1. Things you must do before the first store release

These are blocked on credentials and consoles this repo has no access to.
**All three are irreversible after publishing**, so do them now, not later.

### 1.1 Create a release keystore

`android/app/build.gradle.kts` now signs release builds with the real keystore
whenever `android/key.properties` exists, and prints a loud warning when it
falls back to debug signing. Create the keystore once:

```bash
keytool -genkey -v -keystore ~/siller-center-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (already git-ignored):

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=upload
storeFile=/absolute/path/to/siller-center-upload.jks
```

Verify:

```bash
flutter build appbundle --release
```

> **Back the .jks file up somewhere outside this repo.** Losing it means you can
> never publish an update to the same listing again.

### 1.2 Application ID & Namespace (Configured)

Both platforms now ship under your verified application ID:

| Where | Configured value |
|---|---|
| `android/app/build.gradle.kts` (`namespace`, `applicationId`) | `com.kuwaitcosmetics.seller` |
| `android/app/src/main/kotlin/.../MainActivity.kt` (package) | `com.kuwaitcosmetics.seller` |
| `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) | `com.kuwaitcosmetics.seller` |
| App Name (`AndroidManifest.xml`, `Info.plist`) | `Seller Center` |

### 1.3 Move to your own Firebase project

The committed Firebase config belongs to a different business:

- `android/app/google-services.json` → project `syria-pharmacy-ce885`, and it
  contains a client for `com.syriapharmacy.app`
- `ios/GoogleService-Info.plist` → project `sixvally-ecommerce`, the upstream
  template's demo project

The iOS one is the more urgent of the two: `ios/Runner/AppDelegate.swift` calls
`FirebaseApp.configure()` natively and that plist is in the Runner build phase,
so the native default app is configured from the template's project before Dart
runs — push tokens and analytics can end up somewhere you do not control.

After picking your application ID:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Register **both** platforms so `firebase.json`, `lib/firebase_options.dart`,
`google-services.json` and `GoogleService-Info.plist` are all regenerated
together. Crashlytics is already wired in `lib/main.dart` and starts reporting
as soon as the project is yours.

---

## 2. Build and release

```bash
flutter pub get
flutter analyze                       # must be clean; CI enforces this
dart run tool/check_translations.dart # key parity between en.json and ar.json
flutter test

flutter build appbundle --release     # Play Store
flutter build apk --release           # sideloading
```

The version shown in-app and used for the forced-update check is read from the
platform package at runtime (`lib/helper/version_helper.dart`), so the single
source of truth is `version:` in `pubspec.yaml`. Bump it there and nowhere else.

> **The app version must stay at or above the backend's published minimum.**
> Admin → Business Settings → App Settings publishes `seller_app_version_control`
> (production currently requires **14.1**). The splash screen compares the
> installed version against it *before* routing anywhere, so a `pubspec.yaml`
> version below that minimum shows `UpdateScreen` and no seller can reach the
> login form at all — there is no way past it in-app.
>
> This is what locked sellers out while `pubspec.yaml` read `1.1.0`: the older
> hardcoded `AppConstants.appVersion = '16.2.1'` had been masking the check, so
> the mismatch only surfaced once the real package version started being used.
> `test/app_version_gate_test.dart` now fails the build if the shipped version
> drops below the documented minimum. Lower the admin setting first if you ever
> want the app on a lower version line.

**Toolchain used for this work:** Flutter 3.47.0 stable / Dart 3.11, AGP 8.13.2,
Kotlin 2.2.21, Gradle 8.14.3. The themes use `CardThemeData` and
`DialogThemeData`, which need Flutter 3.27 or newer.

Both `flutter build apk --debug` and `flutter build apk --release` were run
against this tree and succeed; the release APK is 51.7 MB with R8 and resource
shrinking enabled.

### Keeping the Android toolchain current

Flutter enforces a minimum AGP and Kotlin version and raises it over time. The
project was on AGP 8.10.0 and Kotlin 2.2.10, both below what Flutter 3.47
requires, so the build failed outright on any current Flutter. CI now pins
Flutter so this cannot happen silently again.

When you bump the pinned Flutter version in `.github/workflows/ci.yml`, bump
`android/settings.gradle.kts` in the same commit and run `flutter build apk
--debug` before pushing. Two known follow-ups:

- Kotlin 2.2.21 draws a "will soon be dropped" warning; Flutter wants 2.3.20+.
- Gradle 8.14.3 draws the same warning; Flutter wants 9.1.0+.

Neither fails the build today. Both are version bumps in
`android/settings.gradle.kts` and `android/gradle/wrapper/gradle-wrapper.properties`
respectively — do them one at a time with a build in between.

### Two Android build settings worth knowing about

- `android.enableJetifier=true` is still required: something in the dependency
  tree pulls the pre-AndroidX `com.android.support:support-compat:25.3.1`, which
  collides with `androidx.core` when Jetifier is off. Turning it off is a real
  build speedup once that dependency is found and replaced.
- `android/build.gradle.kts` pins every Android library subproject to
  `compileSdk 36`. Some transitive plugins (e.g. `flutter_keyboard_visibility`)
  still hardcode android-31, which fails the AAR metadata check against
  AndroidX libraries that require 34+.

---

## 3. Deliberately left alone

Each of these is a real improvement that was skipped because it means rewriting
a working flow that could not be exercised in this environment (no device, no
Android SDK). They are listed in the order I would tackle them.

| Item | Why it was skipped | What it needs |
|---|---|---|
| `package:http` → Dio for multipart uploads (18 call sites) | Product images, shop banners and registration uploads all go through it. A mistake breaks uploads silently. | Add a `postMultipart` helper on `DioClient`, migrate one call site, test an upload on a device, then do the rest. |
| `autocomplete_textfield` → `flutter_typeahead` (2 sites) | Both packages are already in the project; the abandoned one is used in the add-product form. | Replace the two widgets in `add_product_next_screen.dart` and `add_product_seo_screen.dart`, then drop the dependency. |
| `flutter_xlider` → a maintained range slider | Used for the product price-range filter. | Swap in `RangeSlider` from Flutter itself; the API is close. |
| Remaining 15 screens on `PaginatedListViewWidget` | `LazyPaginatedListView` exists and the orders and products screens (the two heaviest) are on it. The rest are lower traffic. | Follow the diff on `order_screen.dart`: drop the `SingleChildScrollView`, pass `itemCount` + `itemBuilder`. |
| Splitting the 1,395-line and 1,093-line `build()` methods in the add-product and POS screens | Purely mechanical, but large and untestable here. | Extract each visual section into its own widget. |
| Server-side pagination for transactions and reviews | The screens still load the full history; the endpoints need `offset`/`limit` support confirmed on the backend first. | Add the parameters to the repository, then wire `LazyPaginatedListView`. |

---

## 4. What changed in this pass

Grouped by the commit that made each change; `git log` has the detail.

**Crashes and data loss**
- Wallet screen threw a `FormatException` on any amount at or above 1,000,000
  (`double.parse("1.50M")`) — at Syrian pound scale that is every real balance
- POS checkout dereferenced a null response on network failure, throwing
  mid-payment; sales made offline are now queued and replayed automatically
- Connection errors, bad certificates and 429s produced an empty message that
  the UI then suppressed, so failed requests were completely invisible
- The splash screen hung forever if the config request failed

**Security**
- The account password was stored in plaintext `SharedPreferences` and read back
  into the login form; it now lives in the Keystore/Keychain and is wiped on
  logout, with any legacy plaintext value migrated then erased
- `FlutterDownloader` ran with `ignoreSsl: true`; iOS disabled App Transport
  Security for every host
- 47 release-mode `print()` calls logged withdrawal payloads, order amounts and
  saved addresses to the device log

**Arabic**
- No bundled font contained a single Arabic glyph; Cairo is now the app font
- The backend was told the country code (`sa`) instead of the language code
  (`ar`), and no localization header was sent at all
- 21 translation keys rendered as raw `snake_case` on screen
- Dates rendered in English regardless of locale
- 56 paddings and 47 alignments converted to their directional equivalents

**Performance**
- The Home tab re-fired ~16 API calls on every tab switch
- Responses were parsed two or three times each on the main isolate
- Lists built every loaded row at once instead of lazily

**Features**
- Offline sales outbox with a visible unsynced count and manual retry
- CSV export for transactions and the VAT report
- Date-range filter on transactions (the controller and API already supported it;
  there was simply no UI)
- Chat refreshes live when a message push arrives
- The low-stock banner can now actually appear (`productCount < 0` → `> 0`)

**Design system**
- `AppGlass` theme extension carrying blur, tint, border, three shadow tiers and
  semantic gradients, defined for both themes
- Glass surface widgets, stat cards and a hero panel
- Both themes rebuilt on the tokens; dark mode no longer uses light-mode shimmer
  colours or a near-white placeholder fill
- System text scaling honoured up to 1.3x instead of being switched off

**Tooling**
- 13 unit tests (the previous single test was the Flutter counter boilerplate and
  failed against this app)
- `tool/check_translations.dart` and a GitHub Actions workflow
- Analyzer issues down from 185 to 49, with zero errors and zero warnings
