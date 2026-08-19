import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
}

abstract final class AppElevation {
  static const double card = 1;
}

// `AppMotion` (quick/standard durations) was declared here and consumed by
// nothing — the council round of 2026-08-06 found it referenced only at its own
// declaration. It was removed rather than tested: the only test possible against
// an unused constant is `expect(AppMotion.quick, Duration(milliseconds: 150))`,
// which asserts the literal against itself and would have made #17's "coberto
// por teste" true in letter and empty in substance. Reinstate it when a screen
// actually animates, with the animation as its test.

abstract final class AppIcons {
  static const IconData terminal = Icons.terminal_rounded;
  static const IconData status = Icons.check_circle_outline_rounded;
  static const IconData projects = Icons.folder_outlined;
  static const IconData work = Icons.assignment_outlined;
  static const IconData conversations = Icons.forum_outlined;
  static const IconData account = Icons.person_outline_rounded;
  static const IconData decisions = Icons.rule_rounded;
  static const IconData server = Icons.dns_outlined;
  static const IconData session = Icons.badge_outlined;
  static const IconData unreachable = Icons.error_outline_rounded;

  /// The device could not do something the operator asked of it — distinct
  /// from [unreachable], which is the *server* not answering.
  static const IconData warning = Icons.warning_amber_rounded;

  static const IconData issues = Icons.flag_outlined;
  static const IconData artifacts = Icons.inventory_2_outlined;
  static const IconData activity = Icons.history_rounded;

  /// Paired with relative-time text (`RelativeMoment`) wherever data is
  /// marked stale — never color alone.
  static const IconData stale = Icons.schedule_outlined;
}
