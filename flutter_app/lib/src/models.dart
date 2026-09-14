/// Typed models for the curated catalog parsed from the repository README.
library;

class LibraryEntry {
  const LibraryEntry({
    required this.name,
    required this.url,
    required this.description,
    required this.language,
    required this.category,
    this.subcategory,
  });

  final String name;
  final String url;
  final String description;
  final String language;
  final String category;
  final String? subcategory;

  String get groupLabel =>
      subcategory == null ? category : '$category · $subcategory';
}

class StrategyEntry {
  const StrategyEntry({
    required this.title,
    required this.file,
    this.sharpe,
    this.volatility,
    this.rebalancing,
    this.paperUrl,
    this.assetClass,
  });

  final String title;

  /// File name inside `static/strategies/` (bundled as `assets/strategies/`).
  final String file;
  final double? sharpe;
  final String? volatility;
  final String? rebalancing;
  final String? paperUrl;
  final String? assetClass;
}

class BookEntry {
  const BookEntry({
    required this.title,
    required this.url,
    required this.category,
    this.reviews,
    this.rating,
  });

  final String title;
  final String url;
  final String category;
  final String? reviews;
  final double? rating;
}

class VideoEntry {
  const VideoEntry({required this.title, required this.url, this.likes});

  final String title;
  final String url;
  final String? likes;
}

class LinkEntry {
  const LinkEntry({required this.title, required this.url});

  final String title;
  final String url;
}

/// Section titles as written in the README (h1 headings), so tab labels
/// follow the content language automatically.
class CatalogTitles {
  const CatalogTitles({
    this.libraries = 'Libraries',
    this.strategies = 'Strategies',
    this.books = 'Books',
    this.videos = 'Videos',
    this.blogs = 'Blogs',
    this.courses = 'Courses',
  });

  final String libraries;
  final String strategies;
  final String books;
  final String videos;
  final String blogs;
  final String courses;
}

class Catalog {
  const Catalog({
    required this.libraries,
    required this.strategies,
    required this.books,
    required this.videos,
    required this.blogs,
    required this.courses,
    required this.titles,
  });

  final List<LibraryEntry> libraries;
  final List<StrategyEntry> strategies;
  final List<BookEntry> books;
  final List<VideoEntry> videos;
  final List<LinkEntry> blogs;
  final List<LinkEntry> courses;
  final CatalogTitles titles;
}

/// A strategy as shown in the explorer: every bundled implementation file,
/// enriched with README table metadata when available.
class StrategyItem {
  const StrategyItem({required this.file, required this.title, this.entry});

  final String file;
  final String title;
  final StrategyEntry? entry;

  double? get sharpe => entry?.sharpe;
  String? get assetClass => entry?.assetClass;
}

/// Header documentation extracted from a strategy source file.
class StrategyDoc {
  const StrategyDoc({this.sourceUrl, this.description = ''});

  final String? sourceUrl;
  final String description;
}
