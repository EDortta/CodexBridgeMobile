import 'package:codex_bridge_mobile/app/auth_gateway_binding.dart';
import 'package:codex_bridge_mobile/features/auth/data/http_auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/data/mock_auth_gateway.dart';
import 'package:codex_bridge_mobile/features/auth/domain/auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// [resolveAuthGateway] is the decision behind [authGatewayBinding], the
/// binding that closes `security-threat-model.md` finding R2 (a release build
/// authenticating against [MockAuthGateway]). `kReleaseMode` never flips
/// inside a single test process, so this is the only way either branch gets
/// exercised by a test at all.
void main() {
  test('a release build resolves to the real HTTP gateway', () {
    final AuthGateway gateway = resolveAuthGateway(
      releaseMode: true,
      now: DateTime.timestamp,
      resolveServer: () async => null,
    );

    expect(gateway, isA<HttpAuthGateway>());
  });

  test('a non-release build resolves to the mock gateway', () {
    final AuthGateway gateway = resolveAuthGateway(
      releaseMode: false,
      now: DateTime.timestamp,
      resolveServer: () async => null,
    );

    expect(gateway, isA<MockAuthGateway>());
  });
}
