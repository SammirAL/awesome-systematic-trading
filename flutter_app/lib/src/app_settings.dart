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
    required this.analysis,
    required this.goldTitle,
    required this.goldIntro,
    required this.askTitle,
    required this.askHint,
    required this.askButton,
    required this.stop,
    required this.thinking,
    required this.askUnavailable,
    required this.playbookTitle,
    required this.howApplies,
    required this.synthesisTitle,
    required this.synthesisBody,
    required this.disclaimer,
    required this.truncatedNote,
    required this.stoppedNote,
    required this.rateLimitedNote,
    required this.askFailedNote,
    required this.viewCode,
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
  final String analysis;
  final String goldTitle;
  final String goldIntro;
  final String askTitle;
  final String askHint;
  final String askButton;
  final String stop;
  final String thinking;
  final String askUnavailable;
  final String playbookTitle;
  final String howApplies;
  final String synthesisTitle;
  final String synthesisBody;
  final String disclaimer;
  final String truncatedNote;
  final String stoppedNote;
  final String rateLimitedNote;
  final String askFailedNote;
  final String viewCode;

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
    analysis: 'Gold',
    goldTitle: 'Gold — systematic analysis',
    goldIntro:
        'Every catalog strategy that can trade gold, on one page — plus a '
        'direct line to Claude for a complete written analysis built on '
        'those same strategies.',
    askTitle: 'Ask for a complete analysis',
    askHint:
        'Ask in any language — e.g. “Analyse complète de l’or selon ces '
        'stratégies”.',
    askButton: 'Ask Claude',
    stop: 'Stop',
    thinking: 'Thinking…',
    askUnavailable:
        'Live analysis runs on the published web app (claude.ai). In this '
        'build, the playbook below is always available.',
    playbookTitle: 'Gold playbook — applicable strategies',
    howApplies: 'Applied to gold:',
    synthesisTitle: 'Putting it together',
    synthesisBody:
        'A systematic gold sleeve typically combines trend (10-month moving '
        'average), 12-month time-series momentum and curve carry, rebalanced '
        'monthly, with skewness / return-asymmetry as satellite signals. '
        'Note that gold usually trades in contango, so the term-structure '
        'signal is often short gold, hedging the trend sleeve. Sharpe and '
        'volatility figures shown are for the full multi-asset '
        'implementations from the catalog, not for gold alone.',
    disclaimer:
        'Educational summary of published research — not investment advice.',
    truncatedNote: 'The answer was cut short — ask for less at a time.',
    stoppedNote: 'Stopped.',
    rateLimitedNote: 'Usage limit reached — try again in a few minutes.',
    askFailedNote: 'The analysis could not be completed. Try again later.',
    viewCode: 'View code',
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
    analysis: '黄金',
    goldTitle: '黄金——系统化分析',
    goldIntro: '目录中所有适用于黄金的策略汇总在一页，并可直接请 Claude 基于这些策略撰写完整分析。',
    askTitle: '请求完整分析',
    askHint: '可用任何语言提问，例如“基于这些策略对黄金做完整分析”。',
    askButton: '询问 Claude',
    stop: '停止',
    thinking: '思考中…',
    askUnavailable: '实时分析在已发布的网页版（claude.ai）上可用；本地版本始终提供下方的策略手册。',
    playbookTitle: '黄金策略手册——适用策略',
    howApplies: '应用于黄金：',
    synthesisTitle: '组合思路',
    synthesisBody:
        '系统化黄金组合通常结合趋势（10 个月均线）、12 个月时间序列动量与期限结构套利，按月再平衡，'
        '偏度/收益不对称作为辅助信号。黄金期货通常处于升水状态，因此期限结构信号往往做空黄金，'
        '对冲趋势部分。表中的夏普比率与波动率来自目录中的完整多资产实现，并非仅针对黄金。',
    disclaimer: '仅为已发表研究的教育性总结，不构成投资建议。',
    truncatedNote: '回答被截断——请一次询问更少内容。',
    stoppedNote: '已停止。',
    rateLimitedNote: '已达到使用上限——请几分钟后再试。',
    askFailedNote: '分析未能完成，请稍后再试。',
    viewCode: '查看代码',
  );
}
