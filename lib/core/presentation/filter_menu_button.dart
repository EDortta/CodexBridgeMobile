import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

/// A compact "Label: value ▾" trigger for a single-select filter menu.
///
/// Extracted out of `features/decisions/presentation/decisions_screen.dart`
/// (#25) once `features/missions/` (#27) needed the identical pattern for
/// its own project/stage/risk/state filters — the same "two genuine
/// consumers" bar this app already applies to `SessionCard` and
/// `project_health_presentation.dart`. Lives in `core/` because two
/// features now share it, and a feature must never import another feature
/// (`docs/architecture/state-architecture.md`).
class FilterMenuButton<T> extends StatelessWidget {
  const FilterMenuButton({
    required this.icon,
    required this.selected,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final IconData icon;
  final T selected;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopupMenuButton<T>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
        for (final T option in options)
          PopupMenuItem<T>(value: option, child: Text(labelOf(option))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: AppRadius.card,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xxs),
            Text(labelOf(selected), style: theme.textTheme.labelMedium),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
