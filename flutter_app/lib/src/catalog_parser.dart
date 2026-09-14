/// Parses the repository README (English or Chinese) into a typed [Catalog].
///
/// The parser is shape-based rather than text-based: rows are classified by
/// what their cells contain (a "Made with" badge → library, a link into
/// `static/strategies/` → strategy, reviews+rating badges → book, a likes
/// badge → video, a bare link → blog/course), so it works unchanged for both
/// README languages.
library;

import 'models.dart';

final _linkRe = RegExp(r'\[([^\]]+)\]\(([^)\s]+?)\)');
final _imageRe = RegExp(r'!\[[^\]]*\]\(([^)\s]+?)\)');
final _codeRe = RegExp(r'`([^`]+)`');
final _strategyFileRe = RegExp(r'\(\./static/strategies/([^)\s]+?)\)');
final _madeWithRe = RegExp(r'Made%20with-([^-]+)-');

/// First `[text](url)` link in a cell, or null.
({String text, String url})? _firstLink(String cell) {
  // Skip image links: strip images first.
  final withoutImages = cell.replaceAll(_imageRe, '');
  final m = _linkRe.firstMatch(withoutImages);
  if (m == null) return null;
  return (text: m.group(1)!.trim(), url: m.group(2)!.trim());
}

/// Cell content with markdown markup removed.
String _plainText(String cell) {
  var text = cell.replaceAll(_imageRe, '');
  text = text.replaceAllMapped(_linkRe, (m) => m.group(1)!);
  text = text.replaceAllMapped(_codeRe, (m) => m.group(1)!);
  return text.replaceAll('**', '').trim();
}

String? _codeContent(String cell) => _codeRe.firstMatch(cell)?.group(1)?.trim();

List<String> _badgeUrls(String cell) =>
    _imageRe.allMatches(cell).map((m) => m.group(1)!).toList();

/// Value of a badgen path segment, e.g. `reviews` in
/// `https://badgen.net/badge/reviews/14%20161/blue` → `14 161`.
String? _badgeValue(List<String> badges, String key) {
  for (final url in badges) {
    final marker = '/badge/$key/';
    final start = url.indexOf(marker);
    if (start < 0) continue;
    final rest = url.substring(start + marker.length);
    final end = rest.indexOf('/');
    final raw = end < 0 ? rest : rest.substring(0, end);
    try {
      return Uri.decodeComponent(raw).trim();
    } on ArgumentError {
      return raw.trim();
    }
  }
  return null;
}

bool _isTableSeparator(String line) {
  final t = line.trim();
  if (!t.contains('-') || !t.contains('|')) return false;
  return RegExp(r'^\|?[\s:|-]+\|?$').hasMatch(t);
}

List<String> _splitCells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return t.split('|').map((c) => c.trim()).toList();
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Catalog parseCatalog(String markdown) {
  final lines = markdown.split('\n');

  final libraries = <LibraryEntry>[];
  final strategies = <StrategyEntry>[];
  final books = <BookEntry>[];
  final videos = <VideoEntry>[];
  final blogs = <LinkEntry>[];
  final courses = <LinkEntry>[];
  final h1Titles = <String>[];

  var h1Index = 0;
  String? h2;
  String? h3;

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    if (line.startsWith('# ')) {
      h1Index++;
      h1Titles.add(_plainText(line.substring(2)));
      h2 = null;
      h3 = null;
      i++;
      continue;
    }
    if (line.startsWith('## ')) {
      h2 = _plainText(line.substring(3));
      h3 = null;
      i++;
      continue;
    }
    if (line.startsWith('### ')) {
      h3 = _plainText(line.substring(4));
      i++;
      continue;
    }

    final isTableStart = line.contains('|') &&
        i + 1 < lines.length &&
        _isTableSeparator(lines[i + 1]);
    if (!isTableStart) {
      i++;
      continue;
    }

    i += 2; // skip header + separator
    while (i < lines.length && lines[i].contains('|') && lines[i].trim().isNotEmpty) {
      final cells = _splitCells(lines[i]);
      i++;
      if (cells.every((c) => c.isEmpty)) continue;
      final row = cells.join(' | ');
      final badges = _badgeUrls(row);

      // Strategy row: links into static/strategies/.
      final strategyFile = _strategyFileRe.firstMatch(row)?.group(1);
      if (strategyFile != null) {
        String? paper;
        for (final cell in cells.reversed) {
          final link = _firstLink(cell);
          if (link != null && link.url.startsWith('http')) {
            paper = link.url;
            break;
          }
        }
        strategies.add(StrategyEntry(
          title: _plainText(cells.first),
          file: strategyFile,
          sharpe: cells.length > 1
              ? double.tryParse(_codeContent(cells[1]) ?? '')
              : null,
          volatility: cells.length > 2 ? _codeContent(cells[2]) : null,
          rebalancing: cells.length > 3 ? _codeContent(cells[3]) : null,
          paperUrl: paper,
          assetClass: h2,
        ));
        continue;
      }

      // Library row: carries a shields.io "Made with" badge.
      final madeWith = _madeWithRe.firstMatch(row);
      if (madeWith != null) {
        final link = _firstLink(cells.first);
        if (link == null) continue;
        String language;
        try {
          language = Uri.decodeComponent(madeWith.group(1)!);
        } on ArgumentError {
          language = madeWith.group(1)!;
        }
        libraries.add(LibraryEntry(
          name: link.text,
          url: link.url,
          description: cells.length > 1 ? _plainText(cells[1]) : '',
          language: _capitalize(language),
          category: h2 ?? (h1Titles.isEmpty ? '' : h1Titles.last),
          subcategory: h3,
        ));
        continue;
      }

      // Book row: reviews + rating badges.
      final rating = _badgeValue(badges, 'rating');
      if (rating != null) {
        final link = _firstLink(cells.first);
        if (link == null) continue;
        books.add(BookEntry(
          title: link.text,
          url: link.url,
          category: h2 ?? '',
          reviews: _badgeValue(badges, 'reviews'),
          rating: double.tryParse(rating),
        ));
        continue;
      }

      // Video row: likes badge.
      final likes = _badgeValue(badges, 'likes');
      if (likes != null) {
        final link = _firstLink(cells.first);
        if (link == null) continue;
        videos.add(VideoEntry(title: link.text, url: link.url, likes: likes));
        continue;
      }

      // Bare link row: blogs (5th section) or courses (6th section).
      final link = _firstLink(cells.first);
      if (link != null) {
        final entry = LinkEntry(title: link.text, url: link.url);
        if (h1Index == 5) blogs.add(entry);
        if (h1Index == 6) courses.add(entry);
      }
    }
  }

  String titleAt(int index, String fallback) =>
      index < h1Titles.length ? h1Titles[index] : fallback;

  return Catalog(
    libraries: libraries,
    strategies: strategies,
    books: books,
    videos: videos,
    blogs: blogs,
    courses: courses,
    titles: CatalogTitles(
      libraries: titleAt(0, 'Libraries'),
      strategies: titleAt(1, 'Strategies'),
      books: titleAt(2, 'Books'),
      videos: titleAt(3, 'Videos'),
      blogs: titleAt(4, 'Blogs'),
      courses: titleAt(5, 'Courses'),
    ),
  );
}

/// Extracts the source URL and description from a strategy file's header
/// comments (the `# https://quantpedia.com/...` block).
StrategyDoc extractStrategyDoc(String code) {
  final lines = code.split('\n');
  final urlRe = RegExp(r'^#\s*(https?://\S+)\s*$');
  for (var i = 0; i < lines.length; i++) {
    final m = urlRe.firstMatch(lines[i].trim());
    if (m == null) continue;
    final description = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final s = lines[j].trim();
      if (!s.startsWith('#')) break;
      final text = s.replaceFirst(RegExp(r'^#+\s?'), '').trim();
      if (text.isEmpty) {
        if (description.isNotEmpty) break;
        continue;
      }
      description.add(text);
    }
    return StrategyDoc(sourceUrl: m.group(1), description: description.join(' '));
  }
  return const StrategyDoc();
}

/// `12-month-cycle.py` → `12 Month Cycle`.
String prettifyFileName(String file) {
  var name = file.endsWith('.py') ? file.substring(0, file.length - 3) : file;
  return name.split('-').map(_capitalize).join(' ');
}
