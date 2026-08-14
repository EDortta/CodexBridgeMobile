import 'package:codex_bridge_mobile/features/server/domain/server_probe_contract.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bodies below are the examples published in the canonical contract
/// (`EDortta/CodexBridge`, `docs/api/codex-bridge.openapi.yaml`, issues #2/#3).
///
/// They are the point of these tests: a parser asserted only against a body
/// this repository invented proves the mock matches the mock
/// (`design-standards.md` §1).
void main() {
  group('ServerHealth', () {
    test('parses the contract example', () {
      final ServerHealth? health = ServerHealth.tryParse(
        '{"status": "ok", "time": "2026-08-10T14:32:07Z"}',
      );

      expect(health, isNotNull);
      expect(health!.isOk, isTrue);
    });

    test('carries a status other than ok instead of collapsing it to false', () {
      final ServerHealth? health = ServerHealth.tryParse(
        '{"status": "starting", "time": "2026-08-10T14:32:07Z"}',
      );

      expect(health, isNotNull);
      expect(health!.isOk, isFalse);
      expect(health.status, 'starting');
    });

    test('ignores members the contract may add later', () {
      final ServerHealth? health = ServerHealth.tryParse(
        '{"status": "ok", "time": "2026-08-10T14:32:07Z", "uptime": 91}',
      );

      expect(health?.isOk, isTrue);
    });

    test('refuses a body that is not a health report', () {
      // Without the required-field check, an unrelated 200 — a proxy's landing
      // page, another service on the same host — would pass as a healthy
      // gateway (`design-standards.md` §6).
      expect(ServerHealth.tryParse('{"nonsense": true}'), isNull);
      expect(ServerHealth.tryParse('{"status": "ok"}'), isNull);
      expect(ServerHealth.tryParse('{"time": "2026-08-10T14:32:07Z"}'), isNull);
      expect(ServerHealth.tryParse('{"status": 1, "time": "x"}'), isNull);
      expect(ServerHealth.tryParse('<html><body>hello</body></html>'), isNull);
      expect(ServerHealth.tryParse('[]'), isNull);
      expect(ServerHealth.tryParse(''), isNull);
    });
  });

  group('ServerApiVersion', () {
    const String contractExample = '''
{
  "application": "codex-bridge-gateway",
  "applicationVersion": "0.1.0",
  "apiVersions": ["v1"],
  "contractVersion": "1.3.0",
  "buildRevision": "b76a391",
  "capabilities": {
    "errorEnvelope": true,
    "deviceAuthorization": false
  },
  "time": "2026-08-10T14:32:07Z"
}
''';

    test('parses the contract example', () {
      final ServerApiVersion? version = ServerApiVersion.tryParse(
        contractExample,
      );

      expect(version, isNotNull);
      expect(version!.application, 'codex-bridge-gateway');
      expect(version.applicationVersion, '0.1.0');
      expect(version.apiVersions, <String>['v1']);
      expect(version.contractVersion, '1.3.0');
      expect(version.buildRevision, 'b76a391');
    });

    test('reads an absent buildRevision as "not reported"', () {
      // The contract says absence means the deployment injected none — never
      // "no build" — so it must not become an empty string on screen.
      final ServerApiVersion? version = ServerApiVersion.tryParse('''
{
  "application": "codex-bridge-gateway",
  "applicationVersion": "0.1.0",
  "apiVersions": ["v1"],
  "contractVersion": "1.3.0",
  "capabilities": {},
  "time": "2026-08-10T14:32:07Z"
}
''');

      expect(version, isNotNull);
      expect(version!.buildRevision, isNull);
    });

    test('ignores capability flags and members it does not know', () {
      // "Unknown flags must be ignored: new ones may be added within a major
      // version." A client that failed here would break on an additive server
      // change, which is exactly what the contract forbids.
      final ServerApiVersion? version = ServerApiVersion.tryParse('''
{
  "application": "codex-bridge-gateway",
  "applicationVersion": "0.2.0",
  "apiVersions": ["v1", "v2"],
  "contractVersion": "1.4.0",
  "capabilities": {"somethingInvented": true},
  "somethingElseInvented": {"nested": [1, 2]},
  "time": "2026-08-10T14:32:07Z"
}
''');

      expect(version, isNotNull);
      expect(version!.apiVersions, <String>['v1', 'v2']);
    });

    test('refuses a body missing a field the contract requires', () {
      expect(ServerApiVersion.tryParse('{"application": "x"}'), isNull);
      expect(
        ServerApiVersion.tryParse('''
{
  "application": "codex-bridge-gateway",
  "applicationVersion": "0.1.0",
  "apiVersions": ["v1"],
  "contractVersion": "1.3.0",
  "time": "2026-08-10T14:32:07Z"
}
'''),
        isNull,
        reason: 'capabilities is required by the contract',
      );
      expect(
        ServerApiVersion.tryParse('''
{
  "application": "codex-bridge-gateway",
  "applicationVersion": "0.1.0",
  "apiVersions": ["v1", 7],
  "contractVersion": "1.3.0",
  "capabilities": {},
  "time": "2026-08-10T14:32:07Z"
}
'''),
        isNull,
        reason: 'a namespace that is not a string is not a namespace',
      );
      expect(ServerApiVersion.tryParse('not json at all'), isNull);
    });
  });
}
