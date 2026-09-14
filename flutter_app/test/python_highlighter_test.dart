import 'dart:io';

import 'package:awesome_systematic_trading/src/python_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tokens always reconstruct the source exactly', () {
    final dir = Directory('assets/strategies');
    final files = dir.listSync().whereType<File>().toList();
    expect(files.length, greaterThanOrEqualTo(60));
    for (final file in files) {
      final source = file.readAsStringSync();
      final joined = tokenizePython(source).map((t) => t.text).join();
      expect(joined, source, reason: 'mismatch for ${file.path}');
    }
  });

  test('classifies core token types', () {
    const source = 'class Foo:\n'
        '    # comment here\n'
        '    def bar(self, x=1.5):\n'
        '        return "text"\n';
    final tokens = tokenizePython(source);

    PyTokenType typeOf(String text) =>
        tokens.firstWhere((t) => t.text == text).type;

    expect(typeOf('class'), PyTokenType.keyword);
    expect(typeOf('def'), PyTokenType.keyword);
    expect(typeOf('return'), PyTokenType.keyword);
    expect(typeOf('self'), PyTokenType.selfRef);
    expect(typeOf('# comment here'), PyTokenType.comment);
    expect(typeOf('"text"'), PyTokenType.string);
    expect(typeOf('1.5'), PyTokenType.number);
    expect(typeOf('Foo'), PyTokenType.plain);
  });

  test('handles triple-quoted strings spanning lines', () {
    const source = 'x = """line1\nline2"""\ny = 2\n';
    final tokens = tokenizePython(source);
    expect(
      tokens.any(
          (t) => t.type == PyTokenType.string && t.text.contains('line2')),
      isTrue,
    );
    expect(tokens.map((t) => t.text).join(), source);
  });
}
