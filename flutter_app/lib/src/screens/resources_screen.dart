import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../models.dart';
import '../widgets/common.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key, required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: catalog.titles.books),
              Tab(text: catalog.titles.videos),
              Tab(text: catalog.titles.blogs),
              Tab(text: catalog.titles.courses),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BooksTab(books: catalog.books),
                _VideosTab(videos: catalog.videos),
                _LinksTab(entries: catalog.blogs),
                _LinksTab(entries: catalog.courses),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BooksTab extends StatelessWidget {
  const _BooksTab({required this.books});

  final List<BookEntry> books;

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;
    final items = <Object>[];
    String? currentCategory;
    for (final book in books) {
      if (book.category != currentCategory) {
        currentCategory = book.category;
        items.add(currentCategory);
      }
      items.add(book);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is String) return GroupHeader(item);
        final book = item as BookEntry;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(book.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (book.rating != null)
                    MetaChip('★ ${book.rating}',
                        color: const Color(0xFF9A6700)),
                  if (book.reviews != null)
                    MetaChip('${book.reviews} ${strings.reviews}'),
                ],
              ),
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, book.url),
          ),
        );
      },
    );
  }
}

class _VideosTab extends StatelessWidget {
  const _VideosTab({required this.videos});

  final List<VideoEntry> videos;

  @override
  Widget build(BuildContext context) {
    final strings = SettingsScope.of(context).strings;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(video.title),
            subtitle: video.likes == null
                ? null
                : Text('${video.likes} ${strings.likes}'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, video.url),
          ),
        );
      },
    );
  }
}

class _LinksTab extends StatelessWidget {
  const _LinksTab({required this.entries});

  final List<LinkEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.link),
            title: Text(entry.title),
            subtitle: Text(hostOf(entry.url)),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, entry.url),
          ),
        );
      },
    );
  }
}
