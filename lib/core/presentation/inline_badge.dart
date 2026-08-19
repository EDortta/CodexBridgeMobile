import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

/// A small icon+text pairing — state, risk, deadline, owner — never
/// conveyed by color alone.
///
/// Extracted out of `features/decisions/presentation/decision_badge.dart`
/// (#25/#26) once `features/missions/` (#27) needed the identical pattern
/// for owner/stage/risk badges on a mission card — the same "two genuine
/// consumers" bar `FilterMenuButton` was already extracted under. Lives in
/// `core/` because two features now share it.
class InlineBadge extends StatelessWidget {
  const InlineBadge({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: AppSpacing.xxs),
        Text(text, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
