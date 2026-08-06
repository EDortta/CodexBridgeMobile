@TestOn('vm')
library;

import 'dart:io';

import 'package:codex_bridge_mobile/core/design/app_tokens.dart';
import 'package:codex_bridge_mobile/core/navigation/app_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #17's acceptance criterion is that screens consume the centralized
/// design values "without local visual constants". Until 2026-08-06 nothing
/// tested it: the council round found zero test references to `AppSpacing`,
/// `AppRadius`, `AppElevation`, `AppMotion` or `AppIcons`, while the issue's
/// closing comment read "Coberto por teste".
///
/// The property is about the *source*, not the rendered pixels: asserting that
/// a padding equals `AppSpacing.xs` passes just as happily against a hardcoded
/// `8`, because the two are the same number. That is the tautology this file
/// exists to avoid — so it reads the source and fails on the literal.
void main() {
  test('no screen hardcodes a visual constant the tokens already name', () {
    final List<String> violations = <String>[];

    for (final File file in _screenSources()) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        for (final MapEntry<String, RegExp> rule in _literalRules.entries) {
          if (rule.value.hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1} — ${rule.key}: ${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Visual constants belong in lib/core/design/app_tokens.dart so one '
          'edit moves the whole product. A literal here is invisible to that '
          'edit and drifts silently.\n${violations.join('\n')}',
    );
  });

  test('every primary destination draws its icon from AppIcons', () {
    // Not a const Set: IconData has no primitive equality, so it cannot be a
    // constant set element. A List with `contains` uses the same `==`.
    const List<IconData> catalogue = <IconData>[
      AppIcons.terminal,
      AppIcons.status,
      AppIcons.projects,
      AppIcons.work,
      AppIcons.conversations,
      AppIcons.account,
      AppIcons.decisions,
    ];

    for (final AppDestination destination in AppDestination.values) {
      expect(
        catalogue,
        contains(destination.icon),
        reason:
            '${destination.label} uses an icon outside AppIcons, so the icon '
            'set is no longer a single decision.',
      );
    }
  });

  test('the spacing scale stays ordered and positive', () {
    const List<double> scale = <double>[
      AppSpacing.xxs,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
    ];

    expect(scale.first, greaterThan(0));
    for (int i = 1; i < scale.length; i++) {
      expect(
        scale[i],
        greaterThan(scale[i - 1]),
        reason:
            'step $i breaks the ascending scale; a non-monotonic scale makes '
            '"one step larger" meaningless at the call site.',
      );
    }
  });
}

/// Presentation sources only. `lib/core/design/` is where the literals are
/// *supposed* to live, so it is excluded.
Iterable<File> _screenSources() sync* {
  for (final String root in <String>['lib/features', 'lib/app']) {
    final Directory directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity;
      }
    }
  }
}

/// Each pattern matches a numeric literal in a position a token already covers.
/// `EdgeInsets.zero` and named constructors without numbers are untouched.
final Map<String, RegExp> _literalRules = <String, RegExp>{
  'hardcoded padding/margin (use AppSpacing)': RegExp(
    r'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*\d',
  ),
  'hardcoded corner radius (use AppRadius)': RegExp(
    r'BorderRadius\.(all|circular)\(\s*(Radius\.circular\(\s*)?\d',
  ),
  'hardcoded elevation (use AppElevation)': RegExp(r'elevation:\s*\d'),
  'hardcoded gap (use AppSpacing)': RegExp(
    r'SizedBox\(\s*(height|width):\s*\d',
  ),
};
