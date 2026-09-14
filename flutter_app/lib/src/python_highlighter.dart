/// Lightweight regex-based Python tokenizer used to syntax-highlight the
/// bundled strategy files. No third-party dependency; a failed match simply
/// leaves text unstyled.
library;

import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

enum PyTokenType { plain, keyword, string, comment, number, selfRef }

class PyToken {
  const PyToken(this.text, this.type);

  final String text;
  final PyTokenType type;
}

const _keywords = <String>{
  'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break',
  'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally',
  'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal',
  'not', 'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield',
};

final _tokenRe = RegExp(
  '"""[\\s\\S]*?"""|'
  "'''[\\s\\S]*?'''|"
  '"(?:\\\\.|[^"\\\\\n])*"|'
  "'(?:\\\\.|[^'\\\\\n])*'|"
  '#[^\n]*|'
  r'\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b|'
  r'[A-Za-z_]\w*',
);

PyTokenType _classify(String token) {
  final first = token[0];
  if (first == '#') return PyTokenType.comment;
  if (first == '"' || first == "'") return PyTokenType.string;
  if (first.codeUnitAt(0) >= 0x30 && first.codeUnitAt(0) <= 0x39) {
    return PyTokenType.number;
  }
  if (_keywords.contains(token)) return PyTokenType.keyword;
  if (token == 'self' || token == 'cls') return PyTokenType.selfRef;
  return PyTokenType.plain;
}

/// Splits [source] into tokens; concatenating the tokens' text always
/// reproduces [source] exactly.
List<PyToken> tokenizePython(String source) {
  final tokens = <PyToken>[];
  var last = 0;
  for (final match in _tokenRe.allMatches(source)) {
    if (match.start > last) {
      tokens.add(PyToken(source.substring(last, match.start), PyTokenType.plain));
    }
    final text = match.group(0)!;
    tokens.add(PyToken(text, _classify(text)));
    last = match.end;
  }
  if (last < source.length) {
    tokens.add(PyToken(source.substring(last), PyTokenType.plain));
  }
  return tokens;
}

/// GitHub-inspired token colors for light and dark themes.
class PythonHighlightTheme {
  const PythonHighlightTheme({
    required this.plain,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.selfRef,
  });

  factory PythonHighlightTheme.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const light = PythonHighlightTheme(
    plain: Color(0xFF1F2328),
    keyword: Color(0xFFCF222E),
    string: Color(0xFF0A3069),
    comment: Color(0xFF6E7781),
    number: Color(0xFF0550AE),
    selfRef: Color(0xFF953800),
  );

  static const dark = PythonHighlightTheme(
    plain: Color(0xFFF0F6FC),
    keyword: Color(0xFFFF7B72),
    string: Color(0xFFA5D6FF),
    comment: Color(0xFF9198A1),
    number: Color(0xFF79C0FF),
    selfRef: Color(0xFFFFA657),
  );

  final Color plain;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color selfRef;

  Color colorFor(PyTokenType type) {
    switch (type) {
      case PyTokenType.keyword:
        return keyword;
      case PyTokenType.string:
        return string;
      case PyTokenType.comment:
        return comment;
      case PyTokenType.number:
        return number;
      case PyTokenType.selfRef:
        return selfRef;
      case PyTokenType.plain:
        return plain;
    }
  }
}

/// Builds highlighted [TextSpan]s for [source] using [theme]; [baseStyle]
/// should be a monospace style.
List<TextSpan> highlightPython(
  String source,
  PythonHighlightTheme theme,
  TextStyle baseStyle,
) {
  return [
    for (final token in tokenizePython(source))
      TextSpan(
        text: token.text,
        style: baseStyle.copyWith(
          color: theme.colorFor(token.type),
          fontStyle: token.type == PyTokenType.comment
              ? FontStyle.italic
              : FontStyle.normal,
        ),
      ),
  ];
}
