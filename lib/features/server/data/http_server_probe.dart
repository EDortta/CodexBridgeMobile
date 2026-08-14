import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/server_certificate.dart';
import '../domain/server_connection_report.dart';
import '../domain/server_probe.dart';
import '../domain/server_probe_contract.dart';
import '../domain/server_url.dart';

/// Live connection test over TLS.
///
/// Deliberately thin: it opens the two probe requests, measures the first, and
/// hands every judgement to the pure functions in `domain/` — `reportFor…` here
/// and in `server_connection_report.dart`. What is left is the part a host-VM
/// test cannot run anyway, and it contains no branch that decides an outcome.
///
/// Certificate verification is **never** disabled: no `badCertificateCallback`
/// is installed, so an untrusted chain fails the handshake and the test reports
/// [ServerConnectionOutcome.untrustedCertificate]. Fail-closed is the right
/// direction here — this channel will carry the operator's session
/// (`security-standards.md` §3, `design-standards.md` §6).
class HttpServerProbe implements ServerProbe {
  const HttpServerProbe({this.timeout = const Duration(seconds: 10)});

  /// Applied to the connection, to each request, and to reading each body: a
  /// server that accepts a socket and then stalls must not hang the screen.
  final Duration timeout;

  /// A probe body is a small JSON object. Reading an unbounded stream from a
  /// host the operator just typed is a denial of service against this app, so
  /// the read stops here rather than at the caller.
  static const int maxProbeBodyBytes = 64 * 1024;

  @override
  Future<ServerConnectionReport> probe(ServerUrl server) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      final _ProbeResponse health = await _get(
        client,
        server.endpoint(ServerProbeEndpoints.health),
      );
      stopwatch.stop();

      final ServerConnectionReport report = reportForHealthResponse(
        statusCode: health.statusCode,
        body: health.body,
        latency: stopwatch.elapsed,
        certificate: health.certificate,
      );
      if (!report.isReachable) {
        return report;
      }

      return report.withApiVersion(await _readVersion(client, server));
    } on Object catch (error) {
      return reportForTransportFailure(error);
    } finally {
      client.close(force: true);
    }
  }

  /// The version lookup fails open: a gateway whose `/health` answers is
  /// reachable even if `/api/version` does not, and the report says the version
  /// is unavailable instead of downgrading the whole result. The opposite
  /// direction — `/health` — stays fail-closed above.
  Future<ServerApiVersion?> _readVersion(
    HttpClient client,
    ServerUrl server,
  ) async {
    try {
      final _ProbeResponse response = await _get(
        client,
        server.endpoint(ServerProbeEndpoints.version),
      );
      if (response.statusCode != 200) {
        return null;
      }
      return ServerApiVersion.tryParse(response.body);
    } on Object {
      return null;
    }
  }

  Future<_ProbeResponse> _get(HttpClient client, Uri uri) async {
    final HttpClientRequest request = await client.getUrl(uri).timeout(timeout);
    // A redirect is not followed: a 30x from https to http would downgrade the
    // channel silently, and a probe that lands somewhere else is not a test of
    // the URL the operator typed. The 30x is reported as it is.
    request.followRedirects = false;
    final HttpClientResponse response = await request.close().timeout(timeout);

    return _ProbeResponse(
      statusCode: response.statusCode,
      body: await _readCappedBody(response).timeout(timeout),
      certificate: _certificateOf(response.certificate),
    );
  }

  static Future<String> _readCappedBody(Stream<List<int>> response) async {
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await for (final List<int> chunk in response) {
      bytes.add(chunk);
      if (bytes.length >= maxProbeBodyBytes) {
        break;
      }
    }
    // A body that is not valid UTF-8 is not a probe body; decoding it leniently
    // lets the contract parser reject it instead of this read throwing.
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  static ServerCertificate? _certificateOf(X509Certificate? certificate) {
    if (certificate == null) {
      return null;
    }
    return ServerCertificate(
      subject: certificate.subject,
      issuer: certificate.issuer,
      validFrom: certificate.startValidity,
      validTo: certificate.endValidity,
    );
  }
}

/// Maps a transport-level failure to a report.
///
/// Pure and public so the mapping — which is the part that decides what the
/// operator is told — is tested directly. The message never carries the
/// exception's own text: an `OSError` string is platform noise, and a
/// `HandshakeException` can quote a remote-supplied certificate.
ServerConnectionReport reportForTransportFailure(Object error) {
  return switch (error) {
    HandshakeException() || CertificateException() => const
      ServerConnectionReport(
        outcome: ServerConnectionOutcome.untrustedCertificate,
        detail:
            'The TLS handshake failed: the certificate is not trusted by this '
            'device. The connection was refused rather than downgraded.',
      ),
    TimeoutException() => const ServerConnectionReport(
      outcome: ServerConnectionOutcome.unreachable,
      detail: 'The server did not answer in time.',
    ),
    SocketException() => const ServerConnectionReport(
      outcome: ServerConnectionOutcome.unreachable,
      detail:
          'No connection could be opened to that host. Check the address, the '
          'port, and that this device can reach the network it is on.',
    ),
    _ => const ServerConnectionReport(
      outcome: ServerConnectionOutcome.unreachable,
      detail: 'The connection test failed before the server answered.',
    ),
  };
}

class _ProbeResponse {
  const _ProbeResponse({
    required this.statusCode,
    required this.body,
    required this.certificate,
  });

  final int statusCode;
  final String body;
  final ServerCertificate? certificate;
}
