import 'server_certificate.dart';
import 'server_probe_contract.dart';

/// What a connection test concluded.
///
/// One value per distinguishable outcome, so the screen never has to render
/// "something went wrong": the issue asks for explicit results, and a boolean
/// cannot tell a refused certificate from a server that is simply not there.
enum ServerConnectionOutcome {
  reachable('Reachable'),
  unreachable('Unreachable'),
  untrustedCertificate('TLS certificate rejected'),
  rejected('Reached, but not a Codex Bridge server');

  const ServerConnectionOutcome(this.label);

  final String label;
}

/// The full result of one connection test.
///
/// Everything is nullable except [outcome] and [detail] because a failed test
/// still produces a report: latency is known once bytes came back, the
/// certificate only once the handshake succeeded, the version only once
/// `GET /api/version` answered. A `null` here means "not established", and the
/// screen says so rather than showing a blank that reads as success.
class ServerConnectionReport {
  const ServerConnectionReport({
    required this.outcome,
    required this.detail,
    this.latency,
    this.certificate,
    this.apiVersion,
  });

  final ServerConnectionOutcome outcome;

  /// Operator-facing explanation.
  ///
  /// Composed only from values this app controls — a status code, a fixed
  /// sentence. It never echoes the response body: the body comes from a host
  /// the operator just typed and is not trusted to end up on a screen or in a
  /// report (`AGENTS.md` §3b).
  final String detail;

  /// Round trip of `GET /health`, or `null` when no response arrived.
  final Duration? latency;

  /// `null` when the handshake did not complete, which is also the case when
  /// the certificate was rejected.
  final ServerCertificate? certificate;

  /// `null` when `GET /api/version` did not answer with a version body.
  final ServerApiVersion? apiVersion;

  bool get isReachable => outcome == ServerConnectionOutcome.reachable;

  ServerConnectionReport withApiVersion(ServerApiVersion? version) {
    return ServerConnectionReport(
      outcome: outcome,
      detail: detail,
      latency: latency,
      certificate: certificate,
      apiVersion: version,
    );
  }
}

/// Turns a `GET /health` response into a report.
///
/// Pure: this is the judgement the connection test makes, separated from the
/// socket it makes it on so it can be tested without one
/// (`design-standards.md` §1).
ServerConnectionReport reportForHealthResponse({
  required int statusCode,
  required String body,
  required Duration latency,
  ServerCertificate? certificate,
}) {
  if (statusCode != _ok) {
    return ServerConnectionReport(
      outcome: ServerConnectionOutcome.rejected,
      detail:
          'The server answered HTTP $statusCode on '
          '${ServerProbeEndpoints.health} instead of $_ok.',
      latency: latency,
      certificate: certificate,
    );
  }

  final ServerHealth? health = ServerHealth.tryParse(body);
  if (health == null) {
    return ServerConnectionReport(
      outcome: ServerConnectionOutcome.rejected,
      detail:
          'The server answered $_ok, but the body is not a Codex Bridge '
          'health report. Check that the URL points at the gateway.',
      latency: latency,
      certificate: certificate,
    );
  }

  if (!health.isOk) {
    return ServerConnectionReport(
      outcome: ServerConnectionOutcome.rejected,
      detail:
          'The gateway answered, but reports a health status other than "ok".',
      latency: latency,
      certificate: certificate,
    );
  }

  return ServerConnectionReport(
    outcome: ServerConnectionOutcome.reachable,
    detail: 'The gateway is reachable and reports a healthy process.',
    latency: latency,
    certificate: certificate,
  );
}

const int _ok = 200;
