import 'server_url.dart';

/// Where the selected Codex Bridge server is remembered between launches.
abstract interface class ServerConfigStore {
  /// The server the operator selected, or `null` when none is selected.
  ///
  /// A stored value that no longer parses reads as `null` rather than throwing:
  /// an app that cannot open its settings screen is worse than one that asks
  /// for the URL again (`design-standards.md` §6).
  Future<ServerUrl?> readSelectedServer();

  /// Takes a [ServerUrl], not a string, so an unvalidated URL cannot be
  /// persisted by any call site — present or future.
  Future<void> writeSelectedServer(ServerUrl server);
}
