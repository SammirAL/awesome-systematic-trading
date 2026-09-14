import 'package:flutter/material.dart';

import 'src/app_settings.dart';
import 'src/catalog_repository.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/libraries_screen.dart';
import 'src/screens/resources_screen.dart';
import 'src/screens/strategies_screen.dart';
import 'src/widgets/common.dart';

void main() {
  runApp(const AwesomeApp());
}

class AwesomeApp extends StatefulWidget {
  const AwesomeApp({super.key});

  @override
  State<AwesomeApp> createState() => _AwesomeAppState();
}

class _AwesomeAppState extends State<AwesomeApp> {
  final AppSettings _settings = AppSettings();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp(
          title: 'Awesome Systematic Trading',
          debugShowCheckedModeBanner: false,
          themeMode: _settings.themeMode,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF0B67D0),
            brightness: Brightness.light,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: const Color(0xFF0B67D0),
            brightness: Brightness.dark,
            fontFamily: 'Roboto',
          ),
          home: const AppShell(),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final strings = settings.strings;
    final brightness = Theme.of(context).brightness;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final destinations = <({IconData icon, String label})>[
      (icon: Icons.home_outlined, label: strings.home),
      (icon: Icons.widgets_outlined, label: strings.libraries),
      (icon: Icons.query_stats, label: strings.strategies),
      (icon: Icons.collections_bookmark_outlined, label: strings.resources),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.candlestick_chart_outlined),
            SizedBox(width: 8),
            Flexible(
              child: Text('Awesome Systematic Trading',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => settings.setChinese(!settings.chinese),
            icon: const Icon(Icons.translate, size: 18),
            label: Text(settings.chinese ? 'EN' : 'ZH'),
          ),
          IconButton(
            tooltip: 'Theme',
            icon: Icon(brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => settings.toggleTheme(brightness),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) =>
                  setState(() => _index = index),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
      body: FutureBuilder<LoadedCatalog>(
        future: CatalogRepository.load(chinese: settings.chinese),
        initialData: CatalogRepository.resolved(chinese: settings.chinese),
        builder: (context, snapshot) {
          if (snapshot.hasError) return CenteredNote(strings.loadError);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = snapshot.data!;
          final body = IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                loaded: loaded,
                onNavigate: (index) => setState(() => _index = index),
              ),
              LibrariesScreen(libraries: loaded.catalog.libraries),
              StrategiesScreen(loaded: loaded),
              ResourcesScreen(catalog: loaded.catalog),
            ],
          );
          if (!wide) return body;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                        icon: Icon(d.icon), label: Text(d.label)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}
