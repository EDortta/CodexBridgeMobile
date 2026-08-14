import 'server_connection_report.dart';
import 'server_url.dart';

/// Tests whether a Codex Bridge server is there, and what it is.
///
/// The seam that lets the connection test be exercised without a network
/// (`design-standards.md` §2): the screen depends on this interface, the live
/// HTTP implementation lives in `data/`, and a test injects its own.
abstract interface class ServerProbe {
  /// Never throws. A failed test is a [ServerConnectionReport] with a failing
  /// outcome, because the caller of a *connection test* has to render the
  /// failure, not catch it. The promise is stated here so every implementation
  /// is held to it (`design-standards.md` §6).
  Future<ServerConnectionReport> probe(ServerUrl server);
}
