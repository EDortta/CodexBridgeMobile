import 'package:flutter/material.dart';

import '../../../core/design/app_tokens.dart';
import '../domain/project_health.dart';

/// [ProjectHealth]'s color and icon, shared by `_ProjectCard` (#23) and the
/// project dashboard's health header (#24) so the mapping lives in exactly
/// one place. Health is never conveyed by color alone — every caller pairs
/// this color with [projectHealthIcon] and [ProjectHealth.label].
Color projectHealthAccent(ThemeData theme, ProjectHealth health) {
  return switch (health) {
    ProjectHealth.active => theme.colorScheme.outlineVariant,
    ProjectHealth.unhealthy => theme.colorScheme.error,
    ProjectHealth.pendingDecision => theme.colorScheme.tertiary,
    ProjectHealth.offline => theme.colorScheme.outline,
  };
}

IconData projectHealthIcon(ProjectHealth health) {
  return switch (health) {
    ProjectHealth.active => AppIcons.status,
    ProjectHealth.unhealthy => Icons.error_rounded,
    ProjectHealth.pendingDecision => AppIcons.decisions,
    ProjectHealth.offline => AppIcons.unreachable,
  };
}

/// Whether [health] should render with the wider "needs attention" border
/// `_ProjectCard` and the dashboard's health header both use.
bool projectHealthNeedsAttention(ProjectHealth health) {
  return health == ProjectHealth.unhealthy ||
      health == ProjectHealth.pendingDecision;
}
