# Awesome Systematic Trading — Flutter app

A native, cross-platform app (Android, iOS, Windows, macOS, Linux, Web) for
browsing the [Awesome Systematic Trading](../README.md) catalog: the full
curated list rendered as native Material 3 UI, plus a searchable explorer for
the 61 bundled strategy implementations with a syntax-highlighted code viewer.

| Screen | What you get |
|--------|--------------|
| **Home** | Catalog stats, quick navigation, project links |
| **Libraries** | 100+ libraries, grouped as in the README, filterable by language and free-text search |
| **Strategies** | All 61 QuantConnect (LEAN) algorithms with Sharpe / volatility / rebalancing metadata, sortable and filterable by asset class |
| **Strategy detail** | Description extracted from the source, paper link, copy button, syntax-highlighted code with line numbers |
| **Resources** | Books (ratings + review counts), videos (likes), blogs and courses |

Content language toggles between English and 中文 (both READMEs are bundled);
light and dark themes follow a single seed color.

## Run it

```bash
cd flutter_app
flutter run                    # pick any connected device / desktop / chrome
```

Release builds:

```bash
flutter build apk              # Android
flutter build web --release    # Web (see note below)
flutter build linux|macos|windows|ipa
tool/build_web.sh              # Web build, one command
```

## Design decisions

- **The README is the single source of truth.** `lib/src/catalog_parser.dart`
  parses the bundled `README.md` / `README_zh.md` into typed models at
  runtime. The parser is *shape-based* (it classifies table rows by what the
  cells contain, not by section names), which is why the same code handles
  both languages.
- **Offline-first, supply-chain minimal.** The only third-party dependency is
  `url_launcher` (maintained by the Flutter team). Roboto and Roboto Mono are
  bundled as assets, and `web/flutter_bootstrap.js` pins CanvasKit to the
  files shipped in the build — so the web build makes **zero CDN requests**
  and works fully offline. (Known limit: on the *web* build with no network,
  CJK glyphs for the 中文 content need the engine's font fallback, which does
  require network; native builds use system fonts and are fine.)
- **Syntax highlighting** is a ~100-line regex tokenizer
  (`lib/src/python_highlighter.dart`) with a round-trip guarantee tested
  against all 61 bundled files.

## Content assets

`assets/content/`, `assets/strategies/` and `assets/images/` are copies of the
repository content. After editing the READMEs or strategies at the repo root,
re-sync with:

```bash
tool/sync_assets.sh
```

## Tests

```bash
flutter analyze && flutter test
```

Covers: catalog parsing for both languages (entry counts, known values,
every referenced strategy file present), strategy-doc extraction, tokenizer
round-trip over all bundled sources, token classification, and an app boot
smoke test.
