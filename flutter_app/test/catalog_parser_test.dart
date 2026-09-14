import 'dart:io';

import 'package:awesome_systematic_trading/src/catalog_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = File('assets/content/README.md').readAsStringSync();
  final zh = File('assets/content/README_zh.md').readAsStringSync();

  test('parses the English catalog', () {
    final catalog = parseCatalog(en);

    expect(catalog.libraries.length, greaterThanOrEqualTo(90));
    expect(catalog.strategies.length, greaterThanOrEqualTo(40));
    expect(catalog.books.length, greaterThanOrEqualTo(50));
    expect(catalog.videos.length, greaterThanOrEqualTo(20));
    expect(catalog.blogs, isNotEmpty);
    expect(catalog.courses, isNotEmpty);

    final vnpy = catalog.libraries.firstWhere((l) => l.name == 'vnpy');
    expect(vnpy.language, 'Python');
    expect(vnpy.url, 'https://github.com/vnpy/vnpy');
    expect(vnpy.category, isNotEmpty);

    final tsm = catalog.strategies
        .firstWhere((s) => s.file == 'time-series-momentum-effect.py');
    expect(tsm.sharpe, closeTo(0.576, 1e-9));
    expect(tsm.volatility, '20.5%');
    expect(tsm.rebalancing, 'Monthly');
    expect(tsm.paperUrl, startsWith('https://'));

    expect(catalog.titles.strategies, 'Strategies');
    expect(catalog.books.every((b) => b.url.startsWith('http')), isTrue);
  });

  test('parses the Chinese catalog with the same shape', () {
    final catalog = parseCatalog(zh);

    expect(catalog.libraries.length, greaterThanOrEqualTo(90));
    expect(catalog.strategies.length, greaterThanOrEqualTo(40));
    expect(catalog.books.length, greaterThanOrEqualTo(50));
    expect(catalog.videos, isNotEmpty);
    expect(catalog.blogs, isNotEmpty);
    expect(catalog.courses, isNotEmpty);
    expect(catalog.titles.strategies, '战略');

    final tsm = catalog.strategies
        .firstWhere((s) => s.file == 'time-series-momentum-effect.py');
    expect(tsm.sharpe, closeTo(0.576, 1e-9));
  });

  test('every strategy referenced in the README is bundled', () {
    final catalog = parseCatalog(en);
    for (final strategy in catalog.strategies) {
      expect(
        File('assets/strategies/${strategy.file}').existsSync(),
        isTrue,
        reason: '${strategy.file} missing from assets/strategies/',
      );
    }
  });

  test('extracts strategy doc headers', () {
    final code =
        File('assets/strategies/fx-carry-trade.py').readAsStringSync();
    final doc = extractStrategyDoc(code);
    expect(doc.sourceUrl, 'https://quantpedia.com/strategies/fx-carry-trade/');
    expect(doc.description, contains('investment universe'));
  });

  test('prettifies file names', () {
    expect(prettifyFileName('fx-carry-trade.py'), 'Fx Carry Trade');
    expect(prettifyFileName('pairs-trading-with-stocks'),
        'Pairs Trading With Stocks');
  });
}
