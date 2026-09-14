/// Non-web implementation: the artifact runtime only exists in a browser
/// page, so asking Claude is never available here.
library;

import 'claude_bridge_types.dart';

Future<bool> claudeSampleAvailable() async => false;

AskSession startAsk(String prompt, {required void Function(String) onText}) {
  throw UnsupportedError('Claude sampling is only available on the web build');
}
