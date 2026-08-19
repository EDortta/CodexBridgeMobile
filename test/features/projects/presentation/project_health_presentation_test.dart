import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/features/projects/domain/project_health.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/project_health_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ThemeData theme = AppTheme.light();

  test('every health value maps to a distinct icon', () {
    final Set<IconData> icons = ProjectHealth.values.map(projectHealthIcon).toSet();

    expect(icons, hasLength(ProjectHealth.values.length));
  });

  test('every health value maps to a distinct accent color', () {
    final Set<Color> colors = ProjectHealth.values
        .map((ProjectHealth h) => projectHealthAccent(theme, h))
        .toSet();

    expect(colors, hasLength(ProjectHealth.values.length));
  });

  test('only unhealthy and pendingDecision need attention', () {
    expect(projectHealthNeedsAttention(ProjectHealth.active), isFalse);
    expect(projectHealthNeedsAttention(ProjectHealth.unhealthy), isTrue);
    expect(projectHealthNeedsAttention(ProjectHealth.pendingDecision), isTrue);
    expect(projectHealthNeedsAttention(ProjectHealth.offline), isFalse);
  });
}
