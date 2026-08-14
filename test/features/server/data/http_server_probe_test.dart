@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:codex_bridge_mobile/features/server/data/http_server_probe.dart';
import 'package:codex_bridge_mobile/features/server/domain/server_connection_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// The probe's transport-failure mapping.
///
/// `not validated:` the `dart:io` round trip itself. Exercising it would need a
/// live TLS endpoint — a self-signed one means committing a private key, which
/// `security-standards.md` §1 forbids even for a test. So the decision was
/// extracted into [reportForTransportFailure] and pinned here, and what remains
/// unexercised is the socket, not a branch that chooses an outcome.
void main() {
  test('a rejected certificate is reported as such, never as "unreachable"', () {
    // The distinction is the point: "unreachable" invites the operator to
    // retry, while a refused certificate is a trust decision that retrying
    // cannot fix and that must not be worked around.
    final ServerConnectionReport report = reportForTransportFailure(
      const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
    );

    expect(report.outcome, ServerConnectionOutcome.untrustedCertificate);
    expect(report.certificate, isNull);
    expect(report.latency, isNull);
  });

  test('a certificate exception maps to the same outcome', () {
    expect(
      reportForTransportFailure(const CertificateException('bad cert')).outcome,
      ServerConnectionOutcome.untrustedCertificate,
    );
  });

  test('a timeout and a socket failure are both unreachable', () {
    expect(
      reportForTransportFailure(TimeoutException('slow')).outcome,
      ServerConnectionOutcome.unreachable,
    );
    expect(
      reportForTransportFailure(
        const SocketException('Connection refused'),
      ).outcome,
      ServerConnectionOutcome.unreachable,
    );
  });

  test('an unforeseen failure still produces a report, never a throw', () {
    // ServerProbe promises never to throw. A failure class nobody anticipated
    // must degrade to a report, not to a crashed settings screen.
    final ServerConnectionReport report = reportForTransportFailure(
      StateError('something nobody planned for'),
    );

    expect(report.outcome, ServerConnectionOutcome.unreachable);
    expect(report.detail, isNotEmpty);
  });

  test('no failure message quotes the exception it came from', () {
    // An OSError string is platform noise, and a HandshakeException can quote a
    // remote-supplied certificate straight onto the screen.
    const String marker = 'REMOTE-SUPPLIED-MARKER';
    final List<Object> failures = <Object>[
      const HandshakeException(marker),
      const CertificateException(marker),
      TimeoutException(marker),
      const SocketException(marker),
      StateError(marker),
    ];

    for (final Object failure in failures) {
      expect(reportForTransportFailure(failure).detail, isNot(contains(marker)));
    }
  });

  test('the probe caps how much of an untrusted body it will read', () {
    expect(HttpServerProbe.maxProbeBodyBytes, lessThanOrEqualTo(1024 * 1024));
    expect(HttpServerProbe.maxProbeBodyBytes, greaterThan(0));
  });
}
