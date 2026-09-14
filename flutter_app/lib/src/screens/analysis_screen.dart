import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../catalog_repository.dart';
import '../claude_bridge/claude_bridge.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'strategy_detail_screen.dart';

/// Catalog strategies that can trade gold, with how each signal applies.
/// Keyed by file name so it works for both content languages.
class _GoldSignal {
  const _GoldSignal(this.file, this.note);

  final String file;
  final String note;
}

const _goldPlaybook = <_GoldSignal>[
  _GoldSignal(
    'asset-class-trend-following.py',
    'Hold gold (e.g. GLD) only while it trades above its 10-month simple '
        'moving average; otherwise sit in cash.',
  ),
  _GoldSignal(
    'time-series-momentum-effect.py',
    'Go long gold futures when their own trailing 12-month excess return is '
        'positive, short when negative, scaled to a volatility target — the '
        'classic TSMOM rule.',
  ),
  _GoldSignal(
    'momentum-effect-in-commodities.py',
    'Rank gold’s trailing 12-month return inside the commodity '
        'universe; hold it while it sits in the top group.',
  ),
  _GoldSignal(
    'term-structure-effect-in-commodities.py',
    'Trade the futures curve: long backwardated markets, short contangoed '
        'ones. Gold usually sits in contango, so this signal is often short '
        'gold — a hedge to the trend sleeve.',
  ),
  _GoldSignal(
    'skewness-effect-in-commodities.py',
    'Compute the 12-month skewness of gold’s daily returns; low or '
        'negative skew argues for a long position, high positive skew for a '
        'short.',
  ),
  _GoldSignal(
    'return-asymmetry-effect-in-commodity-futures.py',
    'A refined upside-vs-downside asymmetry measure replaces plain skewness '
        'for the same long/short call on gold.',
  ),
  _GoldSignal(
    'asset-class-momentum-rotational-system.py',
    'Include gold in a five-ETF universe and hold it for the next month '
        'whenever its 12-month momentum ranks in the top three.',
  ),
  _GoldSignal(
    'value-and-momentum-factors-across-asset-classes.py',
    'Combine value (long-run reversal) and momentum signals on gold inside '
        'a cross-asset-class long/short portfolio.',
  ),
];

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.loaded});

  final LoadedCatalog loaded;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TextEditingController _question = TextEditingController();
  bool? _sampleAvailable;
  AskSession? _session;
  bool _asking = false;
  String _answer = '';
  String? _note;

  @override
  void initState() {
    super.initState();
    claudeSampleAvailable().then((available) {
      if (mounted) setState(() => _sampleAvailable = available);
    });
  }

  @override
  void dispose() {
    _session?.stop();
    _question.dispose();
    super.dispose();
  }

  List<StrategyItem> _playbookItems() {
    final byFile = {for (final s in widget.loaded.strategies) s.file: s};
    return [
      for (final signal in _goldPlaybook)
        if (byFile[signal.file] != null) byFile[signal.file]!,
    ];
  }

  String _noteFor(String file) =>
      _goldPlaybook.firstWhere((s) => s.file == file).note;

  String _buildPrompt(UiStrings strings) {
    final lines = <String>[];
    for (final item in _playbookItems()) {
      final entry = item.entry;
      final metrics = [
        if (entry?.sharpe != null) 'Sharpe ${entry!.sharpe}',
        if (entry?.volatility != null) 'volatility ${entry!.volatility}',
        if (entry?.rebalancing != null) '${entry!.rebalancing} rebalancing',
      ].join(', ');
      lines.add('- ${item.title}'
          '${metrics.isEmpty ? '' : ' ($metrics)'}: ${_noteFor(item.file)}'
          '${entry?.paperUrl == null ? '' : ' Paper: ${entry!.paperUrl}'}');
    }
    final question = _question.text.trim();
    return 'You are the research assistant inside the "Awesome Systematic '
        'Trading" app. Using ONLY the catalog strategies listed below as '
        'your framework, write a complete, structured analysis of GOLD as a '
        'systematic trading asset, with these sections: 1) Executive '
        'summary. 2) Signal-by-signal review — one short subsection per '
        'strategy, saying what that signal typically implies for gold and '
        'quoting its catalog metrics. 3) A combined gold sleeve — how the '
        'signals fit together, an allocation sketch, rebalancing cadence '
        'and the main risks. 4) Limitations of this framework. Keep it '
        'factual and educational; do not invent live market data or '
        'current prices; end with a one-line disclaimer that this is not '
        'investment advice. Answer in the same language as the user '
        'question below.\n\nCatalog strategies:\n${lines.join('\n')}\n\n'
        'User question: ${question.isEmpty ? 'Complete analysis of gold '
            'according to these strategies.' : question}';
  }

  void _ask(UiStrings strings) {
    if (_asking) return;
    setState(() {
      _asking = true;
      _answer = strings.thinking;
      _note = null;
    });
    final session = startAsk(
      _buildPrompt(strings),
      onText: (text) {
        if (mounted && _asking) setState(() => _answer = text);
      },
    );
    _session = session;
    session.done.then((result) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _answer = result.text;
        if (result.truncated) _note = strings.truncatedNote;
      });
    }).catchError((Object error) {
      if (!mounted) return;
      final e = error is ClaudeAskError
          ? error
          : const ClaudeAskError('upstream_error');
      setState(() {
        _asking = false;
        _answer = e.partialText ?? '';
        if (e.isCancelled) {
          _note = strings.stoppedNote;
        } else if (e.hidesFeature) {
          _sampleAvailable = false;
          _note = null;
        } else if (e.code == 'rate_limited') {
          _note = strings.rateLimitedNote;
        } else {
          _note = strings.askFailedNote;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;
    final theme = Theme.of(context);
    final items = _playbookItems();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_outlined,
                size: 30, color: const Color(0xFFB8860B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.goldTitle,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(strings.goldIntro,
            style: TextStyle(color: theme.colorScheme.outline)),
        const SizedBox(height: 16),
        _AskCard(
          strings: strings,
          available: _sampleAvailable,
          asking: _asking,
          answer: _answer,
          note: _note,
          controller: _question,
          onAsk: () => _ask(strings),
          onStop: () => _session?.stop(),
        ),
        const SizedBox(height: 20),
        Text(
          strings.playbookTitle,
          style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (item.entry?.sharpe != null)
                        SharpeChip(
                            label: strings.sharpe,
                            sharpe: item.entry!.sharpe!),
                      if (item.entry?.volatility != null)
                        MetaChip(
                            '${strings.volatility} ${item.entry!.volatility}'),
                      if (item.entry?.rebalancing != null)
                        MetaChip(item.entry!.rebalancing!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${strings.howApplies} ${_noteFor(item.file)}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StrategyDetailScreen(item: item),
                          ),
                        ),
                        icon: const Icon(Icons.code, size: 18),
                        label: Text(strings.viewCode),
                      ),
                      if (item.entry?.paperUrl != null)
                        TextButton.icon(
                          onPressed: () =>
                              openUrl(context, item.entry!.paperUrl!),
                          icon: const Icon(Icons.description_outlined,
                              size: 18),
                          label: Text(strings.openPaper),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.synthesisTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(strings.synthesisBody),
                const SizedBox(height: 10),
                Text(
                  strings.disclaimer,
                  style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.strings,
    required this.available,
    required this.asking,
    required this.answer,
    required this.note,
    required this.controller,
    required this.onAsk,
    required this.onStop,
  });

  final UiStrings strings;
  final bool? available;
  final bool asking;
  final String answer;
  final String? note;
  final TextEditingController controller;
  final VoidCallback onAsk;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = available == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(strings.askTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: enabled && !asking,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: strings.askHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onSubmitted: enabled && !asking ? (_) => onAsk() : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: enabled && !asking ? onAsk : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(strings.askButton),
                ),
                const SizedBox(width: 8),
                if (asking)
                  OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(strings.stop),
                  ),
                if (asking) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (available == false) ...[
              const SizedBox(height: 10),
              Text(
                strings.askUnavailable,
                style: TextStyle(
                    color: theme.colorScheme.outline, fontSize: 13),
              ),
            ],
            if (answer.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(answer),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!,
                  style: TextStyle(
                      color: theme.colorScheme.outline, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
