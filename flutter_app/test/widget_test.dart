import 'package:awesome_systematic_trading/main.dart';
import 'package:awesome_systematic_trading/src/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and renders the home screen', (tester) async {
    // Asset I/O does not progress inside the test's fake-async zone, so warm
    // the repository cache in a real-async block first.
    final loaded =
        await tester.runAsync(() => CatalogRepository.load(chinese: false));
    expect(loaded, isNotNull);
    expect(loaded!.strategies.length, 61);
    expect(loaded.catalog.libraries.length, greaterThanOrEqualTo(90));

    await tester.pumpWidget(const AwesomeApp());
    await tester.pump(); // FutureBuilder resolves from the warmed cache.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Awesome Systematic Trading'), findsWidgets);
    expect(find.text('Strategies'), findsWidgets);
  });
}
