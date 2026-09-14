/// Entry point for asking Claude from the page (artifact "sample"
/// capability). On non-web platforms this resolves to a stub that reports
/// the feature as unavailable, so the UI degrades to the static playbook.
library;

export 'claude_bridge_stub.dart'
    if (dart.library.js_interop) 'claude_bridge_web.dart';
export 'claude_bridge_types.dart';
