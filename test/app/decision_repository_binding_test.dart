import 'package:codex_bridge_mobile/app/decision_repository_binding.dart';
import 'package:codex_bridge_mobile/features/decisions/data/http_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/data/mock_decision_repository.dart';
import 'package:codex_bridge_mobile/features/decisions/domain/decision_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [resolveDecisionRepository] is the decision behind
/// [decisionRepositoryBinding], the binding that gives a release build a real
/// decisions repository instead of [MockDecisionRepository] — same shape as
/// `resolveAuthGateway`/`authGatewayBinding`. `kReleaseMode` never flips
/// inside a single test process, so this is the only way either branch gets
/// exercised by a test at all.
void main() {
  test('a release build resolves to the real HTTP repository', () {
    final DecisionRepository repository = resolveDecisionRepository(
      releaseMode: true,
      resolveContext: () async => null,
    );

    expect(repository, isA<HttpDecisionRepository>());
  });

  test('a non-release build resolves to the mock repository', () {
    final DecisionRepository repository = resolveDecisionRepository(
      releaseMode: false,
      resolveContext: () async => null,
    );

    expect(repository, isA<MockDecisionRepository>());
  });
}
