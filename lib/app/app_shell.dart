import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_tokens.dart';
import '../core/navigation/app_destinations.dart';
import '../core/navigation/app_routes.dart';

/// Persistent frame around the primary destinations.
///
/// The shell owns the navigation bar and the Decisions entry point, so both
/// are structurally present on every destination instead of being repeated —
/// and eventually forgotten — by each screen.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  /// Branch container built by `StatefulShellRoute.indexedStack`; each branch
  /// keeps its own navigator, which is what preserves a destination's
  /// navigation state while another destination is on screen.
  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Re-selecting the current destination pops it back to its root; selecting
    // another one restores that branch's existing stack.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Decisions',
        onPressed: () => context.push(AppRoutes.decisions),
        child: const Icon(AppIcons.decisions),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: <Widget>[
          for (final AppDestination destination in AppDestination.values)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
