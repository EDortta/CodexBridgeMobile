import 'package:codex_bridge_mobile/app/issue_repository_binding.dart';
import 'package:codex_bridge_mobile/features/issues/data/http_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/data/mock_issue_repository.dart';
import 'package:codex_bridge_mobile/features/issues/domain/issue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [resolveIssueRepository] is the decision behind [issueRepositoryBinding],
/// the same `kReleaseMode` switch `resolveAuthGateway`
/// (`test/app/auth_gateway_binding_test.dart`) tests for auth — that file's
/// own doc comment explains why a plain function is the only way either
/// branch gets exercised by a test at all.
void main() {
  test('a release build resolves to the real HTTP repository', () {
    final IssueRepository repository = resolveIssueRepository(
      releaseMode: true,
      resolveContext: () async => null,
    );

    expect(repository, isA<HttpIssueRepository>());
  });

  test('a non-release build resolves to the mock repository', () {
    final IssueRepository repository = resolveIssueRepository(
      releaseMode: false,
      resolveContext: () async => null,
    );

    expect(repository, isA<MockIssueRepository>());
  });
}
