import 'package:codex_bridge_mobile/features/server/domain/server_certificate.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_connection_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Test results are explicit" is issue #21's second acceptance criterion.
///
/// The judgement lives in [reportForHealthResponse] rather than inside the HTTP
/// adapter precisely so it can be pinned here, without a socket.
void main() {
  const Duration latency = Duration(milliseconds: 42);
  final ServerCertificate certificate = ServerCertificate(
    subject: 'CN=gateway.example.com',
    issuer: "CN=R3, O=Let's Encrypt",
    validFrom: DateTime.utc(2026, 7, 1),
    validTo: DateTime.utc(2026, 9, 29),
  );
  const String healthy = '{"status": "ok", "time": "2026-08-10T14:32:07Z"}';

  test('a healthy gateway is reachable, with its latency and certificate', () {
    final ServerConnectionReport report = reportForHealthResponse(
      statusCode: 200,
      body: healthy,
      latency: latency,
      certificate: certificate,
    );

    expect(report.outcome, ServerConnectionOutcome.reachable);
    expect(report.isReachable, isTrue);
    expect(report.latency, latency);
    expect(report.certificate, same(certificate));
    expect(report.detail, isNotEmpty);
  });

  test('a non-200 status is rejected, and names the status', () {
    final ServerConnectionReport report = reportForHealthResponse(
      statusCode: 404,
      body: '',
      latency: latency,
      certificate: certificate,
    );

    expect(report.outcome, ServerConnectionOutcome.rejected);
    expect(report.detail, contains('404'));
    expect(
      report.latency,
      latency,
      reason:
          'bytes came back, so the round trip was measured; discarding it '
          'would hide that the host is up and the path is wrong',
    );
  });

  test('a 200 that is not a health body is rejected, not accepted', () {
    // The failure this prevents: pointing at a captive portal, a proxy error
    // page, or another service on the same host and reading "reachable".
    final ServerConnectionReport report = reportForHealthResponse(
      statusCode: 200,
      body: '<html><body>Welcome to nginx</body></html>',
      latency: latency,
    );

    expect(report.outcome, ServerConnectionOutcome.rejected);
    expect(report.isReachable, isFalse);
  });

  test('a gateway reporting an unhealthy status is rejected', () {
    final ServerConnectionReport report = reportForHealthResponse(
      statusCode: 200,
      body: '{"status": "starting", "time": "2026-08-10T14:32:07Z"}',
      latency: latency,
    );

    expect(report.outcome, ServerConnectionOutcome.rejected);
  });

  test('no report echoes the server body back to the operator', () {
    // The body comes from a host the operator just typed. It is data, never
    // text this app repeats (`AGENTS.md` §3b).
    const String marker = 'REFLECTED-MARKER';
    final List<ServerConnectionReport> reports = <ServerConnectionReport>[
      reportForHealthResponse(
        statusCode: 200,
        body: '{"status": "$marker", "time": "2026-08-10T14:32:07Z"}',
        latency: latency,
      ),
      reportForHealthResponse(statusCode: 200, body: marker, latency: latency),
      reportForHealthResponse(statusCode: 500, body: marker, latency: latency),
    ];

    for (final ServerConnectionReport report in reports) {
      expect(report.detail, isNot(contains(marker)));
    }
  });

  test('withApiVersion keeps every fact already established', () {
    final ServerConnectionReport report = reportForHealthResponse(
      statusCode: 200,
      body: healthy,
      latency: latency,
      certificate: certificate,
    ).withApiVersion(null);

    expect(report.outcome, ServerConnectionOutcome.reachable);
    expect(report.latency, latency);
    expect(report.certificate, same(certificate));
    expect(report.apiVersion, isNull);
  });

  test('every outcome carries a label a screen can render', () {
    for (final ServerConnectionOutcome outcome
        in ServerConnectionOutcome.values) {
      expect(outcome.label, isNotEmpty);
    }
  });
}
