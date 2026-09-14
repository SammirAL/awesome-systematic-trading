import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../catalog_repository.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.loaded,
    required this.onNavigate,
  });

  final LoadedCatalog loaded;

  /// Jump to a shell tab (1 = libraries, 2 = strategies, 3 = resources).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;
    final catalog = loaded.catalog;
    final stats = <(_Stat, int)>[
      ((label: catalog.titles.libraries, icon: Icons.widgets_outlined, tab: 1),
          catalog.libraries.length),
      ((label: catalog.titles.strategies, icon: Icons.query_stats, tab: 2),
          loaded.strategies.length),
      ((label: catalog.titles.books, icon: Icons.menu_book_outlined, tab: 4),
          catalog.books.length),
      ((label: catalog.titles.videos, icon: Icons.play_circle_outline, tab: 4),
          catalog.videos.length),
      ((label: catalog.titles.blogs, icon: Icons.rss_feed, tab: 4),
          catalog.blogs.length),
      ((label: catalog.titles.courses, icon: Icons.school_outlined, tab: 4),
          catalog.courses.length),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/awesome-systematic-trading.jpeg',
                height: 190,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Awesome Systematic Trading',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(strings.tagline),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 3 : 2;
            final width =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (stat, count) in stats)
                  SizedBox(
                    width: width,
                    child: _StatCard(
                      label: stat.label,
                      count: count,
                      icon: stat.icon,
                      onTap: () => onNavigate(stat.tab),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(strings.repository),
                subtitle: const Text('github.com/paperswithbacktest/awesome-systematic-trading'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context,
                    'https://github.com/paperswithbacktest/awesome-systematic-trading'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.trending_up),
                title: Text(strings.moreStrategies),
                subtitle: const Text('paperswithbacktest.com'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context, 'https://paperswithbacktest.com'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _Stat = ({String label, IconData icon, int tab});

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.outline, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
