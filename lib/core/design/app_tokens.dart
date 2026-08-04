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

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
}

abstract final class AppIcons {
  static const IconData terminal = Icons.terminal_rounded;
  static const IconData status = Icons.check_circle_outline_rounded;
  static const IconData projects = Icons.folder_outlined;
  static const IconData work = Icons.assignment_outlined;
  static const IconData conversations = Icons.forum_outlined;
  static const IconData account = Icons.person_outline_rounded;
  static const IconData decisions = Icons.rule_rounded;
}
