import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../catalog_repository.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'strategy_detail_screen.dart';

enum StrategySort { sharpe, name, volatility }

class StrategiesScreen extends StatefulWidget {
  const StrategiesScreen({super.key, required this.loaded});

  final LoadedCatalog loaded;

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  String _query = '';
  StrategySort _sort = StrategySort.sharpe;
  String? _assetClass;

  double _volatilityOf(StrategyItem item) {
    final raw = item.entry?.volatility?.replaceAll('%', '');
    return double.tryParse(raw ?? '') ?? double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;

    final assetClasses = <String>[];
    for (final item in widget.loaded.strategies) {
      final assetClass = item.assetClass;
      if (assetClass != null && !assetClasses.contains(assetClass)) {
        assetClasses.add(assetClass);
      }
    }

    final query = _query.toLowerCase();
    final items = widget.loaded.strategies.where((item) {
      if (_assetClass != null && item.assetClass != _assetClass) return false;
      if (query.isEmpty) return true;
      return ('${item.title} ${item.file} ${item.assetClass ?? ''}')
          .toLowerCase()
          .contains(query);
    }).toList();

    switch (_sort) {
      case StrategySort.sharpe:
        items.sort((a, b) => (b.sharpe ?? double.negativeInfinity)
            .compareTo(a.sharpe ?? double.negativeInfinity));
      case StrategySort.name:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case StrategySort.volatility:
        items.sort((a, b) => _volatilityOf(a).compareTo(_volatilityOf(b)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = SearchBox(
                hint: strings.searchStrategies,
                onChanged: (value) => setState(() => _query = value),
              );
              final sort = SegmentedButton<StrategySort>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: StrategySort.sharpe,
                      label: Text(strings.sortSharpe)),
                  ButtonSegment(
                      value: StrategySort.name, label: Text(strings.sortName)),
                  ButtonSegment(
                      value: StrategySort.volatility,
                      label: Text(strings.sortVolatility)),
                ],
                selected: {_sort},
                onSelectionChanged: (selection) =>
                    setState(() => _sort = selection.first),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 8), sort],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  sort,
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(strings.all),
                  selected: _assetClass == null,
                  onSelected: (_) => setState(() => _assetClass = null),
                ),
              ),
              for (final assetClass in assetClasses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(assetClass),
                    selected: _assetClass == assetClass,
                    onSelected: (selected) => setState(
                        () => _assetClass = selected ? assetClass : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? CenteredNote(strings.noResults)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _StrategyTile(item: items[index], strings: strings),
                ),
        ),
      ],
    );
  }
}

class _StrategyTile extends StatelessWidget {
  const _StrategyTile({required this.item, required this.strings});

  final StrategyItem item;
  final UiStrings strings;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (entry?.sharpe != null)
                SharpeChip(label: strings.sharpe, sharpe: entry!.sharpe!),
              if (entry?.volatility != null)
                MetaChip('${strings.volatility} ${entry!.volatility}'),
              if (entry?.rebalancing != null) MetaChip(entry!.rebalancing!),
              Text(
                item.file,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.outline,
                  fontFamily: 'RobotoMono',
                  fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StrategyDetailScreen(item: item),
          ),
        ),
      ),
    );
  }
}
