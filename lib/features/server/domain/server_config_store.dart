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

/// The narrow slice of platform secure storage this feature depends on.
///
/// Deliberately two methods wide. The point of the seam is that
/// [ServerConfigStore]'s policy — the key, the encoding, what a corrupt value
/// means — is testable with a fake that implements exactly what the code under
/// test calls, and no stub that is never called (`design-standards.md` §2).
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
