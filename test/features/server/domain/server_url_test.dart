import 'package:codex_bridge_mobile/features/server/domain/server_probe_contract.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #21's first acceptance criterion is "invalid URLs are rejected".
///
/// It is pinned here rather than only through the screen because [ServerUrl] is
/// the single gate: the store and the probe accept the type, not a string, so a
/// rule proven here holds at every call site that exists and every one added
/// later.
void main() {
  group('rejects', () {
    void expectRejected(String raw, ServerUrlRejection reason) {
      final ServerUrlParse parsed = ServerUrl.parse(raw);
      expect(
        parsed,
        isA<ServerUrlRejected>().having(
          (ServerUrlRejected rejected) => rejected.reason,
          'reason',
          reason,
        ),
        reason: '"$raw" should be refused as ${reason.name}',
      );
    }

    test('an empty or blank string', () {
      expectRejected('', ServerUrlRejection.empty);
      expectRejected('   ', ServerUrlRejection.empty);
    });

    test('a bare host with no scheme', () {
      expectRejected('gateway.example.com', ServerUrlRejection.notAbsolute);
      // `Uri` reads `host:port` as `scheme:path` — dots are legal in a scheme —
      // so this arrives as an unsupported scheme, and the message still tells
      // the operator to add https://.
      expectRejected(
        'gateway.example.com:8443',
        ServerUrlRejection.insecureScheme,
      );
    });

    test('cleartext http, which this app can never reach', () {
      // android/app/src/main/res/xml/network_security_config.xml denies
      // cleartext for every build variant, so an accepted http:// URL would
      // fail later as an opaque platform error instead of here as a sentence.
      expectRejected(
        'http://gateway.example.com',
        ServerUrlRejection.insecureScheme,
      );
      expectRejected('ws://gateway.example.com', ServerUrlRejection.insecureScheme);
      expectRejected('file:///etc/passwd', ServerUrlRejection.insecureScheme);
    });

    test('an https URL with no host', () {
      expectRejected('https://', ServerUrlRejection.missingHost);
      expectRejected('https:///health', ServerUrlRejection.missingHost);
    });

    test('credentials embedded in the URL', () {
      // A password in a URL leaks to logs and to anything that renders it, and
      // authentication is issue #22's own flow.
      expectRejected(
        'https://operator:hunter2@gateway.example.com',
        ServerUrlRejection.embeddedCredentials,
      );
    });

    test('a query string or a fragment', () {
      expectRejected(
        'https://gateway.example.com?token=abc',
        ServerUrlRejection.queryOrFragment,
      );
      expectRejected(
        'https://gateway.example.com#section',
        ServerUrlRejection.queryOrFragment,
      );
    });

    test('a string that is not a URL at all', () {
      expectRejected(
        'https://gateway.example.com:port',
        ServerUrlRejection.malformed,
      );
      expectRejected('://gateway.example.com', ServerUrlRejection.malformed);
    });

    test('a host Uri would silently percent-encode instead of refusing', () {
      // `Uri.tryParse` accepts this and reports the host as
      // `gate%20way.example.com`. Left alone it becomes an unexplained
      // "unreachable" at test time instead of a typo the operator can fix.
      expectRejected(
        'https://gate way.example.com',
        ServerUrlRejection.invalidHost,
      );
      expectRejected('https://-gateway.example.com', ServerUrlRejection.invalidHost);
    });

    test('with a message that never echoes what was typed', () {
      // The input may be a pasted credential. A rejection that quotes it puts
      // it on a screen and into any report that carries the message.
      const String secret = 'hunter2';
      for (final ServerUrlRejection reason in ServerUrlRejection.values) {
        expect(reason.message, isNot(contains(secret)));
        expect(reason.message, isNotEmpty);
      }
    });
  });

  group('accepts', () {
    ServerUrl accept(String raw) {
      final ServerUrlParse parsed = ServerUrl.parse(raw);
      expect(parsed, isA<ServerUrlAccepted>(), reason: '"$raw" should be accepted');
      return (parsed as ServerUrlAccepted).url;
    }

    test('a plain https host', () {
      expect(accept('https://gateway.example.com').toString(),
          'https://gateway.example.com');
    });

    test('an explicit port, and drops the implicit one', () {
      expect(accept('https://gateway.example.com:8443').toString(),
          'https://gateway.example.com:8443');
      expect(accept('https://gateway.example.com:443').toString(),
          'https://gateway.example.com');
    });

    test('a reverse-proxy sub-path, and normalizes the trailing slash', () {
      // The gateway is deployed behind nginx in a sub-path, so the base path is
      // part of the address rather than noise to strip.
      expect(accept('https://gateway.example.com/codexbridge/').toString(),
          'https://gateway.example.com/codexbridge');
      expect(accept('https://gateway.example.com///').toString(),
          'https://gateway.example.com');
    });

    test('surrounding whitespace and a mixed-case host', () {
      expect(accept('  https://Gateway.Example.COM  ').toString(),
          'https://gateway.example.com');
    });

    test('an IP literal, for a gateway reached without DNS', () {
      expect(accept('https://192.168.7.200:8443').toString(),
          'https://192.168.7.200:8443');
      expect(accept('https://[::1]:8443').toString(), 'https://[::1]:8443');
    });

    test('so that two spellings of one server compare equal', () {
      expect(accept('https://gateway.example.com/'),
          accept('https://GATEWAY.example.com:443'));
    });
  });

  group('endpoint', () {
    test('resolves the probe paths under a root-hosted gateway', () {
      final ServerUrl url =
          (ServerUrl.parse('https://gateway.example.com') as ServerUrlAccepted)
              .url;

      expect(url.endpoint(ServerProbeEndpoints.health).toString(),
          'https://gateway.example.com/health');
      expect(url.endpoint(ServerProbeEndpoints.version).toString(),
          'https://gateway.example.com/api/version');
    });

    test('keeps the sub-path prefix of a proxied gateway', () {
      // Losing the prefix here would probe the proxy's root and report the
      // wrong server as unreachable — or, worse, as reachable.
      final ServerUrl url = (ServerUrl.parse(
        'https://gateway.example.com/codexbridge',
      ) as ServerUrlAccepted).url;

      expect(url.endpoint(ServerProbeEndpoints.health).toString(),
          'https://gateway.example.com/codexbridge/health');
      expect(url.endpoint(ServerProbeEndpoints.version).toString(),
          'https://gateway.example.com/codexbridge/api/version');
    });
  });
}
