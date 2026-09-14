import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../catalog_parser.dart';
import '../catalog_repository.dart';
import '../models.dart';
import '../python_highlighter.dart';
import '../widgets/common.dart';

class StrategyDetailScreen extends StatefulWidget {
  const StrategyDetailScreen({super.key, required this.item});

  final StrategyItem item;

  @override
  State<StrategyDetailScreen> createState() => _StrategyDetailScreenState();
}

class _StrategyDetailScreenState extends State<StrategyDetailScreen> {
  late final Future<String> _source;

  @override
  void initState() {
    super.initState();
    _source = CatalogRepository.loadStrategySource(widget.item.file);
  }

  Future<void> _copy(String source, String message) async {
    await Clipboard.setData(ClipboardData(text: source));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;
    final entry = widget.item.entry;

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: FutureBuilder<String>(
        future: _source,
        builder: (context, snapshot) {
          if (snapshot.hasError) return CenteredNote(strings.loadError);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final source = snapshot.data!;
          final doc = extractStrategyDoc(source);
          final paperUrl = entry?.paperUrl ?? doc.sourceUrl;
          final lineCount = '\n'.allMatches(source).length + 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry?.sharpe != null)
                          SharpeChip(
                              label: strings.sharpe, sharpe: entry!.sharpe!),
                        if (entry?.volatility != null)
                          MetaChip('${strings.volatility} ${entry!.volatility}'),
                        if (entry?.rebalancing != null)
                          MetaChip(entry!.rebalancing!),
                        if (entry?.assetClass != null)
                          MetaChip(entry!.assetClass!,
                              icon: Icons.category_outlined),
                        MetaChip('$lineCount ${strings.lines}',
                            icon: Icons.notes),
                      ],
                    ),
                    if (doc.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        doc.description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (paperUrl != null)
                          FilledButton.tonalIcon(
                            onPressed: () => openUrl(context, paperUrl),
                            icon: const Icon(Icons.description_outlined,
                                size: 18),
                            label: Text(strings.openPaper),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: () => _copy(source, strings.copied),
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(strings.copyCode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _CodeView(source: source)),
            ],
          );
        },
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightTheme = PythonHighlightTheme.of(theme.brightness);
    final style = codeTextStyle(context);
    final lineCount = '\n'.allMatches(source).length + 1;
    final gutter = List.generate(lineCount, (i) => '${i + 1}').join('\n');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  gutter,
                  textAlign: TextAlign.right,
                  style: style.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  child: SelectableText.rich(
                    TextSpan(
                      style: style,
                      children:
                          highlightPython(source, highlightTheme, style),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
