import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../models.dart';
import '../widgets/common.dart';

class LibrariesScreen extends StatefulWidget {
  const LibrariesScreen({super.key, required this.libraries});

  final List<LibraryEntry> libraries;

  @override
  State<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends State<LibrariesScreen> {
  String _query = '';
  String? _language;

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;

    final languageCounts = <String, int>{};
    for (final lib in widget.libraries) {
      languageCounts.update(lib.language, (n) => n + 1, ifAbsent: () => 1);
    }
    final languages = languageCounts.keys.toList()
      ..sort((a, b) => languageCounts[b]!.compareTo(languageCounts[a]!));

    final query = _query.toLowerCase();
    final filtered = widget.libraries.where((lib) {
      if (_language != null && lib.language != _language) return false;
      if (query.isEmpty) return true;
      return ('${lib.name} ${lib.description} ${lib.groupLabel}')
          .toLowerCase()
          .contains(query);
    }).toList();

    // Group while preserving README order.
    final items = <Object>[];
    String? currentGroup;
    for (final lib in filtered) {
      if (lib.groupLabel != currentGroup) {
        currentGroup = lib.groupLabel;
        items.add(currentGroup);
      }
      items.add(lib);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SearchBox(
            hint: strings.searchLibraries,
            onChanged: (value) => setState(() => _query = value),
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
                  selected: _language == null,
                  onSelected: (_) => setState(() => _language = null),
                ),
              ),
              for (final language in languages)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$language (${languageCounts[language]})'),
                    selected: _language == language,
                    onSelected: (selected) => setState(
                        () => _language = selected ? language : null),
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
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is String) return GroupHeader(item);
                    final lib = item as LibraryEntry;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lib.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            MetaChip(lib.language),
                          ],
                        ),
                        subtitle: lib.description.isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  lib.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        onTap: () => openUrl(context, lib.url),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
