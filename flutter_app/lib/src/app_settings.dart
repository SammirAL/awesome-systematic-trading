/// App-wide user settings (theme mode, content language) plus the small set
/// of fixed UI strings in both languages.
library;

import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _chinese = false;

  ThemeMode get themeMode => _themeMode;
  bool get chinese => _chinese;
  UiStrings get strings => _chinese ? UiStrings.zh : UiStrings.en;

  void toggleTheme(Brightness current) {
    _themeMode =
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setChinese(bool value) {
    if (_chinese == value) return;
    _chinese = value;
    notifyListeners();
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing from the widget tree');
    return scope!.notifier!;
  }
}

class UiStrings {
  const UiStrings({
    required this.home,
    required this.libraries,
    required this.strategies,
    required this.resources,
    required this.tagline,
    required this.searchLibraries,
    required this.searchStrategies,
    required this.all,
    required this.sortSharpe,
    required this.sortName,
    required this.sortVolatility,
    required this.sharpe,
    required this.volatility,
    required this.rebalancing,
    required this.openPaper,
    required this.copyCode,
    required this.copied,
    required this.lines,
    required this.noResults,
    required this.rating,
    required this.reviews,
    required this.likes,
    required this.loadError,
    required this.repository,
    required this.moreStrategies,
  });

  final String home;
  final String libraries;
  final String strategies;
  final String resources;
  final String tagline;
  final String searchLibraries;
  final String searchStrategies;
  final String all;
  final String sortSharpe;
  final String sortName;
  final String sortVolatility;
  final String sharpe;
  final String volatility;
  final String rebalancing;
  final String openPaper;
  final String copyCode;
  final String copied;
  final String lines;
  final String noResults;
  final String rating;
  final String reviews;
  final String likes;
  final String loadError;
  final String repository;
  final String moreStrategies;

  static const en = UiStrings(
    home: 'Home',
    libraries: 'Libraries',
    strategies: 'Strategies',
    resources: 'Resources',
    tagline:
        'Papers, libraries, books, blogs and courses for finding, developing '
        'and running systematic trading strategies.',
    searchLibraries: 'Search libraries…',
    searchStrategies: 'Search strategies… (momentum, crypto, reversal)',
    all: 'All',
    sortSharpe: 'Sharpe',
    sortName: 'Name',
    sortVolatility: 'Volatility',
    sharpe: 'Sharpe',
    volatility: 'Vol',
    rebalancing: 'Rebalancing',
    openPaper: 'Open paper',
    copyCode: 'Copy code',
    copied: 'Code copied to clipboard',
    lines: 'lines',
    noResults: 'Nothing matches this filter.',
    rating: 'rating',
    reviews: 'reviews',
    likes: 'likes',
    loadError: 'Could not load the catalog.',
    repository: 'GitHub repository',
    moreStrategies: 'More strategies on paperswithbacktest.com',
  );

  static const zh = UiStrings(
    home: '首页',
    libraries: '库和包',
    strategies: '策略',
    resources: '资源',
    tagline: '用于寻找、开发和运行系统化交易策略的论文、软件库、书籍、博客和课程。',
    searchLibraries: '搜索库…',
    searchStrategies: '搜索策略…（动量、加密货币、反转）',
    all: '全部',
    sortSharpe: '夏普比率',
    sortName: '名称',
    sortVolatility: '波动率',
    sharpe: '夏普',
    volatility: '波动',
    rebalancing: '再平衡',
    openPaper: '打开论文',
    copyCode: '复制代码',
    copied: '代码已复制到剪贴板',
    lines: '行',
    noResults: '没有匹配的结果。',
    rating: '评分',
    reviews: '评论',
    likes: '点赞',
    loadError: '目录加载失败。',
    repository: 'GitHub 仓库',
    moreStrategies: '更多策略见 paperswithbacktest.com',
  );
}
