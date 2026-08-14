import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/flutter_secure_key_value_store.dart';
import '../data/http_server_probe.dart';
import '../data/secure_server_config_store.dart';
import '../domain/server_config_store.dart';
import '../domain/server_connection_report.dart';
import '../domain/server_probe.dart';
import '../domain/server_url.dart';

/// Everything the server settings screen shows.
///
/// [rejection] and [report] are mutually exclusive by construction of the
/// controller: a URL that was refused was never probed, so the screen can never
/// show a stale success next to a rejection.
class ServerSettings {
  const ServerSettings({
    this.selectedServer,
    this.rejection,
    this.report,
    this.testing = false,
  });

  /// The persisted selection, or `null` when none has been saved.
  final ServerUrl? selectedServer;

  /// Why the last submitted URL was refused, or `null` when it was accepted.
  final ServerUrlRejection? rejection;

  /// Result of the last connection test, or `null` when none has run.
  final ServerConnectionReport? report;

  /// A test is in flight.
  final bool testing;
}

final Provider<SecureKeyValueStore> secureKeyValueStoreProvider =
    Provider<SecureKeyValueStore>((Ref ref) => const FlutterSecureKeyValueStore());

final Provider<ServerConfigStore> serverConfigStoreProvider =
    Provider<ServerConfigStore>(
      (Ref ref) => SecureServerConfigStore(ref.watch(secureKeyValueStoreProvider)),
    );

final Provider<ServerProbe> serverProbeProvider = Provider<ServerProbe>(
  (Ref ref) => const HttpServerProbe(),
);

final AsyncNotifierProvider<ServerSettingsController, ServerSettings>
serverSettingsProvider =
    AsyncNotifierProvider<ServerSettingsController, ServerSettings>(
      ServerSettingsController.new,
    );

/// Owns the two operator actions of issue #21: test a URL, and select it.
///
/// Both start at [ServerUrl.parse], so "invalid URLs are rejected" holds at
/// every entry point rather than at the one that was reviewed
/// (`design-standards.md` §3).
class ServerSettingsController extends AsyncNotifier<ServerSettings> {
  @override
  Future<ServerSettings> build() async {
    final ServerUrl? selected = await ref
        .watch(serverConfigStoreProvider)
        .readSelectedServer();
    return ServerSettings(selectedServer: selected);
  }

  /// Runs a connection test against [raw] without selecting it.
  ///
  /// Testing before saving is the point of the feature, so this deliberately
  /// does not persist anything.
  Future<void> testConnection(String raw) async {
    final ServerUrlParse parsed = ServerUrl.parse(raw);
    if (parsed case ServerUrlRejected(:final ServerUrlRejection reason)) {
      _emit(rejection: reason);
      return;
    }

    final ServerUrl url = (parsed as ServerUrlAccepted).url;
    _emit(testing: true);
    final ServerConnectionReport report = await ref
        .read(serverProbeProvider)
        .probe(url);
    _emit(report: report);
  }

  /// Validates [raw] and, only if it is accepted, persists it as the selected
  /// server.
  ///
  /// A selection is not gated on a successful test: an operator configuring the
  /// app before the gateway is up would otherwise be unable to save at all. The
  /// test result stays on screen next to the selection so the choice is made
  /// with the evidence in view.
  Future<void> select(String raw) async {
    final ServerUrlParse parsed = ServerUrl.parse(raw);
    if (parsed case ServerUrlRejected(:final ServerUrlRejection reason)) {
      _emit(rejection: reason);
      return;
    }

    final ServerUrl url = (parsed as ServerUrlAccepted).url;
    await ref.read(serverConfigStoreProvider).writeSelectedServer(url);
    _emit(selectedServer: url, report: _current.report);
  }

  ServerSettings get _current =>
      state.valueOrNull ?? const ServerSettings();

  /// Every transition is written out in full rather than copied from the
  /// previous state: the fields that must clear — a rejection once the URL is
  /// accepted, a report once a new attempt starts — clear because they are not
  /// carried, not because someone remembered a flag.
  void _emit({
    ServerUrl? selectedServer,
    ServerUrlRejection? rejection,
    ServerConnectionReport? report,
    bool testing = false,
  }) {
    state = AsyncData<ServerSettings>(
      ServerSettings(
        selectedServer: selectedServer ?? _current.selectedServer,
        rejection: rejection,
        report: report,
        testing: testing,
      ),
    );
  }
}
