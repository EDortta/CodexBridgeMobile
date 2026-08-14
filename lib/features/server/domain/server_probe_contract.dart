import 'dart:convert';

/// The slice of the CodexBridge HTTP contract this app needs to answer "can I
/// talk to this server?".
///
/// One file, because there is one reason to change it: the canonical contract
/// (`EDortta/CodexBridge`, `docs/api/codex-bridge.openapi.yaml`, issues #2/#3)
/// moving. Only the two unauthenticated probe endpoints are modelled — the rest
/// of the contract arrives with the features that consume it.
///
/// Every parser here is pure, so the judgement it makes is tested without any
/// I/O; the HTTP round trip around it stays thin on purpose
/// (`design-standards.md` §1).
abstract final class ServerProbeEndpoints {
  /// Liveness probe. Unauthenticated and safe to poll.
  static const String health = '/health';

  /// Version and capability report. Deliberately outside `/api/v1`, so a client
  /// can read it before committing to a namespace.
  static const String version = '/api/version';
}

/// Body of `GET /health`.
class ServerHealth {
  const ServerHealth._(this.status);

  /// `ok` is the only value the contract defines today. Any other value is
  /// carried verbatim rather than collapsed, so the report can name it.
  final String status;

  bool get isOk => status == _okStatus;

  /// Returns `null` when [body] is not a health body.
  ///
  /// `time` is required by the contract and validated for that reason, but it
  /// is not carried: nothing renders it, and a field kept "just in case" is a
  /// field the next reader has to account for. Validating it is what stops an
  /// unrelated JSON object — a proxy's error page, another service's response —
  /// from passing as a health body (`design-standards.md` §6).
  static ServerHealth? tryParse(String body) {
    final Map<String, Object?>? json = _decodeJsonObject(body);
    if (json == null) {
      return null;
    }
    final Object? status = json['status'];
    final Object? time = json['time'];
    if (status is! String || status.isEmpty || time is! String) {
      return null;
    }
    return ServerHealth._(status);
  }

  static const String _okStatus = 'ok';
}

/// Body of `GET /api/version`.
class ServerApiVersion {
  const ServerApiVersion._({
    required this.application,
    required this.applicationVersion,
    required this.apiVersions,
    required this.contractVersion,
    required this.buildRevision,
  });

  /// Name the server reports for itself, e.g. `codex-bridge-gateway`.
  final String application;

  /// Version of the running application, independent of the contract version.
  final String applicationVersion;

  /// Every API namespace this server serves, e.g. `['v1']`.
  final List<String> apiVersions;

  /// Version of the OpenAPI document this build implements.
  final String contractVersion;

  /// Build or commit identifier. `null` means "not reported by this
  /// deployment", never "no build" — the contract is explicit about that.
  final String? buildRevision;

  /// Returns `null` when [body] is not a version body.
  ///
  /// `capabilities` is required by the contract and validated, but not carried:
  /// no screen in this issue reads a capability flag. Unknown members — of the
  /// body and of `capabilities` alike — are ignored, which is what the contract
  /// requires of a client so that additive changes stay non-breaking.
  static ServerApiVersion? tryParse(String body) {
    final Map<String, Object?>? json = _decodeJsonObject(body);
    if (json == null) {
      return null;
    }

    final Object? application = json['application'];
    final Object? applicationVersion = json['applicationVersion'];
    final Object? apiVersions = json['apiVersions'];
    final Object? contractVersion = json['contractVersion'];
    final Object? capabilities = json['capabilities'];
    final Object? time = json['time'];
    final Object? buildRevision = json['buildRevision'];

    if (application is! String ||
        applicationVersion is! String ||
        apiVersions is! List<Object?> ||
        contractVersion is! String ||
        capabilities is! Map<String, Object?> ||
        time is! String) {
      return null;
    }

    final List<String> namespaces = apiVersions.whereType<String>().toList(
      growable: false,
    );
    if (namespaces.length != apiVersions.length) {
      return null;
    }

    return ServerApiVersion._(
      application: application,
      applicationVersion: applicationVersion,
      apiVersions: namespaces,
      contractVersion: contractVersion,
      buildRevision: buildRevision is String && buildRevision.isNotEmpty
          ? buildRevision
          : null,
    );
  }
}

Map<String, Object?>? _decodeJsonObject(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}
