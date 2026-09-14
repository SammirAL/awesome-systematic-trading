/// Shared types for the Claude "sample" bridge (asking Claude from the
/// published artifact page). See claude_bridge.dart for the entry point.
library;

class ClaudeAnswer {
  const ClaudeAnswer({required this.text, required this.truncated});

  final String text;
  final bool truncated;
}

/// Rejection from a sample call. [code] follows the artifact runtime's
/// SampleErrorCode contract; [partialText] is any streamed text the page may
/// keep on screen.
class ClaudeAskError implements Exception {
  const ClaudeAskError(this.code, [this.partialText]);

  final String code;
  final String? partialText;

  bool get isCancelled => code == 'cancelled';

  /// Codes meaning "hide the feature for this view — permanent".
  bool get hidesFeature => const {
        'not_granted',
        'sampling_disabled',
        'not_declared',
        'capability_disabled',
        'capability_removed',
      }.contains(code);

  @override
  String toString() => 'ClaudeAskError($code)';
}

/// One in-flight ask: await [done]; call [stop] to cancel.
abstract class AskSession {
  Future<ClaudeAnswer> get done;
  void stop();
}
