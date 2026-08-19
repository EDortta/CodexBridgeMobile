import 'package:flutter/material.dart';

import '../../../core/design/app_tokens.dart';

/// A small icon+text pairing — state, risk, deadline — never conveyed by
/// color alone. Shared by the inbox card (#25) and the detail screen (#26).
class DecisionBadge extends StatelessWidget {
  const DecisionBadge({required this.icon, required this.text, super.key});

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
