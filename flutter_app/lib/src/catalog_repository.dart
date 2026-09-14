/// Loads and caches the parsed catalog plus the list of bundled strategy
/// implementation files.
library;

import 'package:flutter/services.dart';

import 'catalog_parser.dart';
import 'models.dart';

class LoadedCatalog {
  const LoadedCatalog({required this.catalog, required this.strategies});

  final Catalog catalog;

  /// Every bundled strategy file, enriched with README metadata when the
  /// file appears in a strategy table.
  final List<StrategyItem> strategies;
}

class CatalogRepository {
  CatalogRepository._();

  static final Map<bool, Future<LoadedCatalog>> _cache = {};
  static final Map<bool, LoadedCatalog> _resolved = {};

  static Future<LoadedCatalog> load({required bool chinese}) {
    return _cache.putIfAbsent(chinese, () async {
      final loaded = await _load(chinese: chinese);
      _resolved[chinese] = loaded;
      return loaded;
    });
  }

  /// Synchronously returns an already-loaded catalog, so callers can render
  /// without a loading frame (and widget tests can pre-warm the cache).
  static LoadedCatalog? resolved({required bool chinese}) => _resolved[chinese];

  static Future<LoadedCatalog> _load({required bool chinese}) async {
    final markdown = await rootBundle.loadString(
      chinese ? 'assets/content/README_zh.md' : 'assets/content/README.md',
    );
    final catalog = parseCatalog(markdown);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/strategies/'))
        .map((a) => a.substring('assets/strategies/'.length))
        .toList()
      ..sort();

    final byFile = <String, StrategyEntry>{};
    for (final entry in catalog.strategies) {
      byFile.putIfAbsent(entry.file, () => entry);
    }

    final items = [
      for (final file in files)
        StrategyItem(
          file: file,
          title: byFile[file]?.title ?? prettifyFileName(file),
          entry: byFile[file],
        ),
    ];

    return LoadedCatalog(catalog: catalog, strategies: items);
  }

  static Future<String> loadStrategySource(String file) {
    return rootBundle.loadString('assets/strategies/$file');
  }
}
