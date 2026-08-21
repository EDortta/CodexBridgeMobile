import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_bridge_mobile/app/app.dart';
import 'package:codex_bridge_mobile/app/app_router.dart';
import 'package:codex_bridge_mobile/app/project_dashboard_screen.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context.dart';
import 'package:codex_bridge_mobile/core/gateway/gateway_context_provider.dart';
import 'package:codex_bridge_mobile/core/navigation/app_destinations.dart';
import 'package:codex_bridge_mobile/core/navigation/app_routes.dart';
import 'package:codex_bridge_mobile/features/decisions/presentation/decision_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/epic_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/epics_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issue_detail_screen.dart';
import 'package:codex_bridge_mobile/features/issues/presentation/issues_screen.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_detail_screen.dart';

void main() {
  testWidgets('reaches the four primary destinations from the shell', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    for (final AppDestination destination in AppDestination.values) {
      await tester.tap(_navigationBarItem(destination.label));
      await tester.pumpAndSettle();

      expect(
        _appBarTitle(destination.label),
        findsOneWidget,
        reason: '${destination.label} is not reachable from the shell',
      );
    }
  });

  testWidgets('preserves a destination navigation state across a tab switch', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Codex Bridge Mobile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDashboardScreen), findsOneWidget);

    await tester.tap(_navigationBarItem(AppDestination.work.label));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDashboardScreen), findsNothing);

    await tester.tap(_navigationBarItem(AppDestination.projects.label));
    await tester.pumpAndSettle();
    expect(
      find.byType(ProjectDashboardScreen),
      findsOneWidget,
      reason: 'the Projects branch lost its stack while Work was on screen',
    );
  });

  testWidgets('re-selecting the current destination returns it to its root', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Codex Bridge Mobile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDashboardScreen), findsOneWidget);

    await tester.tap(_navigationBarItem(AppDestination.projects.label));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDashboardScreen), findsNothing);
    expect(_appBarTitle(AppDestination.projects.label), findsOneWidget);
  });

  testWidgets('pops a detail route back to its destination root', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Codex Bridge Mobile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDashboardScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDashboardScreen), findsNothing);
    expect(_appBarTitle(AppDestination.projects.label), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tapping a project card carries its id to the dashboard', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Codex Bridge Mobile'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ProjectDashboardScreen>(find.byType(ProjectDashboardScreen)).projectId,
      'codex-bridge-mobile',
    );
  });

  testWidgets('pops Decisions back to the destination it was opened from', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppDestination.work.path);

    await tester.tap(find.byTooltip('Decisions'));
    await tester.pumpAndSettle();
    expect(_appBarTitle('Decisions'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(_appBarTitle(AppDestination.work.label), findsOneWidget);
  });

  testWidgets('tapping a decision card carries its id to the detail screen', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppDestination.work.path);

    await tester.tap(find.byTooltip('Decisions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve the navigation shell'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DecisionDetailScreen>(find.byType(DecisionDetailScreen))
          .decisionId,
      'shell-review',
    );
  });

  testWidgets('tapping a mission card carries its id to the detail screen', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppDestination.work.path);

    await tester.tap(find.text('Codex Bridge Mobile'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<MissionDetailScreen>(find.byType(MissionDetailScreen))
          .missionId,
      'mobile-foundation',
    );
  });

  testWidgets('tapping an issue card carries its id to the detail screen', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'issues': 'codex-bridge-mobile'},
      ).toString(),
    );

    await tester.tap(find.text('App icon needs a higher-resolution asset'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<IssueDetailScreen>(find.byType(IssueDetailScreen)).issueId,
      'mobile-icon-polish',
    );
  });

  testWidgets('tapping an epic card carries its id to the detail screen', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'epics': 'codex-bridge-mobile'},
      ).toString(),
    );

    await tester.tap(find.text('Epic 06 — Epics, Issues e planejamento'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EpicDetailScreen>(find.byType(EpicDetailScreen)).epicId,
      'epic-mobile-planning',
    );
  });

  testWidgets('toggles between the Epics and Issues views for the same project', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: Uri(
        path: AppDestination.projects.detailPath,
        queryParameters: <String, String>{'epics': 'codex-bridge-mobile'},
      ).toString(),
    );
    expect(find.byType(EpicsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('viewIssuesButton')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<IssuesScreen>(find.byType(IssuesScreen)).projectId,
      'codex-bridge-mobile',
    );

    await tester.tap(find.byKey(const Key('viewEpicsButton')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EpicsScreen>(find.byType(EpicsScreen)).projectId,
      'codex-bridge-mobile',
    );
  });

  testWidgets('resolves a deep-link path to its destination, shell intact', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppDestination.conversations.path);

    expect(
      _appBarTitle(AppDestination.conversations.label),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('resolves a nested deep-link path, shell intact', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppDestination.account.detailPath);

    expect(find.text('Account detail placeholder'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('reaches Decisions from every primary destination', (
    WidgetTester tester,
  ) async {
    for (final AppDestination destination in AppDestination.values) {
      await _pumpApp(tester, initialLocation: destination.path);

      await tester.tap(find.byTooltip('Decisions'));
      await tester.pumpAndSettle();

      expect(
        _appBarTitle('Decisions'),
        findsOneWidget,
        reason: 'Decisions is not reachable from ${destination.label}',
      );
    }
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutes.projects,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        // `projectsProvider` (and `projectByIdProvider`) now need a
        // `GatewayContext` the same way the missions feature's providers
        // already do — this router test exercises navigation, not auth, so
        // it fixes one here rather than routing every scenario through a
        // real sign-in flow.
        gatewayContextProvider.overrideWith(
          (Ref ref) async => GatewayContext(
            server: Uri.parse('https://bridge.example.com'),
            accessToken: 'access-token',
          ),
        ),
      ],
      child: CodexBridgeMobileApp(
        router: createAppRouter(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Targets the navigation bar entry, not the destination's own app bar title,
/// which carries the same text.
Finder _navigationBarItem(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

Finder _appBarTitle(String label) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(label));
