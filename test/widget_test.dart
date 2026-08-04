import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codex_bridge_mobile/app/app.dart';
import 'package:codex_bridge_mobile/app/app_router.dart';
import 'package:codex_bridge_mobile/core/design/app_theme.dart';
import 'package:codex_bridge_mobile/core/design/operational_text_theme.dart';
import 'package:codex_bridge_mobile/core/navigation/app_destinations.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:codex_bridge_mobile/features/missions/domain/mission_repository.dart';
import 'package:codex_bridge_mobile/features/missions/presentation/mission_providers.dart';

void main() {
  testWidgets('shows the operator missions on the Work destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: CodexBridgeMobileApp(
          router: createAppRouter(initialLocation: AppDestination.work.path),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Codex Bridge Mobile'), findsOneWidget);
    expect(find.text('Terminal móvel'), findsOneWidget);
    expect(find.text('mobile-foundation'), findsOneWidget);
    expect(find.text('[ready] Local foundation active'), findsOneWidget);
  });

  testWidgets('uses an injected repository without changing the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          missionRepositoryProvider.overrideWithValue(_FakeMissionRepository()),
        ],
        child: CodexBridgeMobileApp(
          router: createAppRouter(initialLocation: AppDestination.work.path),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Injected mission'), findsOneWidget);
    expect(find.text('[ready] Ready for review'), findsOneWidget);
  });

  test('provides Material 3 themes for light and dark system settings', () {
    final lightTheme = AppTheme.light();
    final darkTheme = AppTheme.dark();

    expect(lightTheme.useMaterial3, isTrue);
    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.extension<OperationalTextTheme>()?.metadata, isNotNull);
    expect(
      lightTheme.extension<OperationalTextTheme>()?.code.fontFamily,
      'monospace',
    );
    expect(
      lightTheme.extension<OperationalTextTheme>()?.log.fontFamily,
      'monospace',
    );
  });
}

class _FakeMissionRepository implements MissionRepository {
  @override
  Future<List<Mission>> loadMissions() {
    return Future<List<Mission>>.value(const <Mission>[
      Mission(
        id: 'injected-mission',
        title: 'Injected mission',
        status: 'Ready for review',
      ),
    ]);
  }
}
