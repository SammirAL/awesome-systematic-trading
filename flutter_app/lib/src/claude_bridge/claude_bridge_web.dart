/// Web implementation of the Claude "sample" bridge, following the artifact
/// runtime contract (0.2.x): `window.claude.use("sample")` resolves a
/// callable namespace or null; calls resolve `{text, truncated}` or reject
/// with a plain `{code, message, text?}` object.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'claude_bridge_types.dart';

@JS('claude')
external JSAny? get _claudeGlobal;

@JS('claude.use')
external JSPromise<JSAny?> _claudeUse(JSString name);

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSAny get signal;
  external void abort();
}

JSFunction? _sampleFn;
Future<bool>? _probe;

Future<bool> claudeSampleAvailable() {
  return _probe ??= () async {
    try {
      final claude = _claudeGlobal;
      if (claude == null || claude.isUndefinedOrNull) return false;
      final resolved = await _claudeUse('sample'.toJS).toDart;
      if (resolved != null && resolved.typeofEquals('function')) {
        _sampleFn = resolved as JSFunction;
        return true;
      }
    } catch (_) {
      // Treat any interop failure as absence.
    }
    return false;
  }();
}

String? _readString(JSObject source, String key) {
  final value = source.getProperty(key.toJS);
  return value.isA<JSString>() ? (value as JSString).toDart : null;
}

class _WebAskSession implements AskSession {
  _WebAskSession(String prompt, void Function(String) onText) {
    final options = JSObject();
    options.setProperty('signal'.toJS, _controller.signal);
    options.setProperty(
      'onText'.toJS,
      ((JSObject update) {
        final text = _readString(update, 'text');
        if (text != null) onText(text);
      }).toJS,
    );
    _done = _call(prompt, options);
  }

  final _AbortController _controller = _AbortController();
  late final Future<ClaudeAnswer> _done;

  Future<ClaudeAnswer> _call(String prompt, JSObject options) async {
    try {
      final promise =
          _sampleFn!.callAsFunction(null, prompt.toJS, options)! as JSPromise;
      final result = (await promise.toDart)! as JSObject;
      final truncated = result.getProperty('truncated'.toJS);
      return ClaudeAnswer(
        text: _readString(result, 'text') ?? '',
        truncated:
            truncated.isA<JSBoolean>() && (truncated as JSBoolean).toDart,
      );
    } catch (error) {
      var code = 'upstream_error';
      String? partial;
      try {
        // A rejected JS promise surfaces its plain {code, message, text?}
        // object here; on web (the only platform compiling this file) the
        // check is well-defined.
        // ignore: invalid_runtime_check_with_js_interop_types
        if (error is JSObject) {
          code = _readString(error, 'code') ?? code;
          partial = _readString(error, 'text');
        }
      } catch (_) {
        // Keep the generic code.
      }
      throw ClaudeAskError(code, partial);
    }
  }

  @override
  Future<ClaudeAnswer> get done => _done;

  @override
  void stop() => _controller.abort();
}

AskSession startAsk(String prompt, {required void Function(String) onText}) {
  if (_sampleFn == null) {
    throw StateError('claudeSampleAvailable() must resolve true first');
  }
  return _WebAskSession(prompt, onText);
}
