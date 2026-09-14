/// Small shared widgets and helpers.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

String hostOf(String url) => Uri.tryParse(url)?.host ?? '';

TextStyle codeTextStyle(BuildContext context) => const TextStyle(
      fontFamily: 'RobotoMono',
      fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
      fontSize: 13,
      height: 1.55,
    );

class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {super.key, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SharpeChip extends StatelessWidget {
  const SharpeChip({super.key, required this.label, required this.sharpe});

  final String label;
  final double sharpe;

  @override
  Widget build(BuildContext context) {
    final color = sharpe >= 0.5
        ? const Color(0xFF1A7F37)
        : sharpe >= 0
            ? const Color(0xFF9A6700)
            : const Color(0xFFCF222E);
    return MetaChip('$label ${sharpe.toStringAsFixed(sharpe.abs() < 10 ? 3 : 1)}',
        icon: Icons.query_stats, color: color);
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CenteredNote extends StatelessWidget {
  const CenteredNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
