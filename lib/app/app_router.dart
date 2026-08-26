import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/app_destinations.dart';
import '../core/navigation/app_routes.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/audit/presentation/audit_trail_screen.dart';
import '../features/auth/presentation/session_screen.dart';
import '../features/conversations/presentation/conversations_screen.dart';
import '../features/decisions/presentation/decision_detail_screen.dart';
import '../features/decisions/presentation/decisions_screen.dart';
import '../features/missions/presentation/work_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/server/presentation/server_settings_screen.dart';
import 'app_shell.dart';
import 'destination_detail_screen.dart';

/// Builds the application router.
///
/// This is the composition root for navigation and the only place allowed to
/// import a feature's `presentation/` layer; features never reach for each
/// other. Keys are created per call so two routers can coexist (for example in
/// a test file) without sharing a [GlobalKey].
///
/// [initialLocation] is the path the app opens on, which is also how a
/// deep-link path is exercised.
GoRouter createAppRouter({String initialLocation = AppRoutes.projects}) {
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        // One branch per destination, in destination order: each branch keeps
        // its own navigator, so a destination's stack survives while another
        // destination is on screen.
        branches: <StatefulShellBranch>[
          for (final AppDestination destination in AppDestination.values)
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(
                debugLabel: destination.name,
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: destination.path,
                  builder: (BuildContext context, GoRouterState state) =>
                      _screenOf(destination),
                  routes: <RouteBase>[
                    GoRoute(
                      path: AppRoutes.detailSegment,
                      builder: (BuildContext context, GoRouterState state) =>
                          DestinationDetailScreen(destination: destination),
                    ),
                    // Server settings and the session belong to one
                    // destination, not to all of them, so they are registered
                    // on the Account branch only.
                    if (destination == AppDestination.account) ...<RouteBase>[
                      GoRoute(
                        path: AppRoutes.serverSegment,
                        builder: (BuildContext context, GoRouterState state) =>
                            const ServerSettingsScreen(),
                      ),
                      GoRoute(
                        path: AppRoutes.sessionSegment,
                        builder: (BuildContext context, GoRouterState state) =>
                            const SessionScreen(),
                      ),
                      GoRoute(
                        path: AppRoutes.auditSegment,
                        builder: (BuildContext context, GoRouterState state) =>
                            const AuditTrailScreen(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
      // Decisions sits above the shell on the root navigator, so it is reached
      // the same way from every destination.
      GoRoute(
        path: AppRoutes.decisions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const DecisionsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.detailSegment,
            builder: (BuildContext context, GoRouterState state) {
              final String decisionId =
                  state.uri.queryParameters['decision'] ?? '';
              return DecisionDetailScreen(decisionId: decisionId);
            },
          ),
        ],
      ),
    ],
  );
}

Widget _screenOf(AppDestination destination) {
  return switch (destination) {
    AppDestination.projects => const ProjectsScreen(),
    AppDestination.work => const WorkScreen(),
    AppDestination.conversations => const ConversationsScreen(),
    AppDestination.account => const AccountScreen(),
  };
}
