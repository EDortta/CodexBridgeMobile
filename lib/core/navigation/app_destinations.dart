import 'package:flutter/widgets.dart';

import '../design/app_tokens.dart';
import 'app_routes.dart';

/// The primary destinations of the application shell.
///
/// Declaration order is the shell's navigation order: the router builds one
/// branch per value in this order, and the navigation bar renders the same
/// list, so a branch index and a destination index can never drift apart.
enum AppDestination {
  projects(
    path: AppRoutes.projects,
    label: 'Projects',
    icon: AppIcons.projects,
  ),
  work(path: AppRoutes.work, label: 'Work', icon: AppIcons.work),
  conversations(
    path: AppRoutes.conversations,
    label: 'Conversations',
    icon: AppIcons.conversations,
  ),
  account(path: AppRoutes.account, label: 'Account', icon: AppIcons.account);

  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;

  /// Absolute path of this destination's detail route.
  String get detailPath => AppRoutes.detailOf(path);
}
