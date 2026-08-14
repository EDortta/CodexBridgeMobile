import 'dart:convert';

/// Where a session is in its life, evaluated against a clock the caller passes.
///
/// One value per action the app must take, so no screen and no controller has
/// to recombine "expired" and "renewable" and get the combination wrong. The
/// clock arrives as a parameter rather than through `DateTime.now()` inside the
/// logic, which is what makes every branch below testable
/// (`design-standards.md` §2).
enum SessionLifecycle {
  /// Valid, and far enough from expiry that nothing has to happen.
  active,

  /// Renewal should be attempted now: the access token is inside its renewal
  /// window or already expired, and the refresh window is still open.
  renewalDue,

  /// The access token expired and the refresh window closed with it. Only a
  /// fresh sign-in recovers from here.
  expired,
}

/// The session this device holds for a Codex Bridge account.
///
/// Carries two secrets. Nothing here renders them and [toString] redacts them,
/// because a value that ends up in a log or an error report is a value that
/// leaked (`docs/limits.md`, security boundary).
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.operatorId,
    required this.operatorName,
  });

  /// Credential presented on an authenticated request. Short-lived.
  final String accessToken;

  /// Credential presented to obtain a new [accessToken]. Longer-lived, and the
  /// only thing standing between an expired session and a new sign-in.
  final String refreshToken;

  /// Instant [accessToken] stops being accepted.
  final DateTime expiresAt;

  /// Instant [refreshToken] stops being accepted. Never renewed by a renewal:
  /// a refresh window that slides forward on every renewal never ends, and a
  /// stolen device would hold a session forever.
  final DateTime refreshExpiresAt;

  /// Identity the *server* resolved the credential to.
  ///
  /// It is never taken from anything the client supplied: an identifier the
  /// client chooses is a suggestion, an identifier the credential resolved to
  /// is a fact (`design-standards.md` §4).
  final String operatorId;

  /// Operator-facing name, shown so the operator can tell which account this
  /// device is linked to.
  final String operatorName;

  /// How early renewal starts, so a request is never sent with a token that
  /// expires while it is in flight.
  static const Duration renewalLeadTime = Duration(minutes: 5);

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Whether the refresh window is still open.
  bool isRenewableAt(DateTime now) => now.isBefore(refreshExpiresAt);

  /// Whether [now] has reached the renewal window ahead of [expiresAt].
  bool needsRenewalAt(DateTime now) =>
      !now.isBefore(expiresAt.subtract(renewalLeadTime));

  /// Total: every combination of the two windows maps to exactly one value, so
  /// a caller switching on the result cannot forget a case.
  SessionLifecycle lifecycleAt(DateTime now) {
    if (isExpiredAt(now)) {
      return isRenewableAt(now)
          ? SessionLifecycle.renewalDue
          : SessionLifecycle.expired;
    }
    if (needsRenewalAt(now) && isRenewableAt(now)) {
      return SessionLifecycle.renewalDue;
    }
    return SessionLifecycle.active;
  }

  /// JSON for secure storage.
  ///
  /// Instants are written in UTC so a device that changes time zone reads back
  /// the same expiry it wrote.
  String encode() => jsonEncode(<String, Object?>{
    _accessTokenKey: accessToken,
    _refreshTokenKey: refreshToken,
    _expiresAtKey: expiresAt.toUtc().toIso8601String(),
    _refreshExpiresAtKey: refreshExpiresAt.toUtc().toIso8601String(),
    _operatorIdKey: operatorId,
    _operatorNameKey: operatorName,
  });

  /// Returns `null` when [encoded] is not a complete session.
  ///
  /// Every field is required and checked. A partially-decoded session is the
  /// dangerous shape: an object with an empty token and a default expiry passes
  /// as a `Session`, so the app believes it is signed in and every request
  /// fails with no path back (`design-standards.md` §6). Unreadable state
  /// therefore means *signed out* — auth fails closed.
  static Session? tryDecode(String encoded) {
    final Object? decoded = _tryDecodeJson(encoded);
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final String? accessToken = _nonEmptyString(decoded[_accessTokenKey]);
    final String? refreshToken = _nonEmptyString(decoded[_refreshTokenKey]);
    final String? operatorId = _nonEmptyString(decoded[_operatorIdKey]);
    final String? operatorName = _nonEmptyString(decoded[_operatorNameKey]);
    final DateTime? expiresAt = _instant(decoded[_expiresAtKey]);
    final DateTime? refreshExpiresAt = _instant(decoded[_refreshExpiresAtKey]);

    if (accessToken == null ||
        refreshToken == null ||
        operatorId == null ||
        operatorName == null ||
        expiresAt == null ||
        refreshExpiresAt == null) {
      return null;
    }

    return Session(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      refreshExpiresAt: refreshExpiresAt,
      operatorId: operatorId,
      operatorName: operatorName,
    );
  }

  /// Redacted on purpose. `toString` is what a crash report, a `print` and a
  /// failing `expect` all reach for; none of them is a place for a token.
  @override
  String toString() =>
      'Session(operatorId: $operatorId, expiresAt: ${expiresAt.toUtc()}, '
      'refreshExpiresAt: ${refreshExpiresAt.toUtc()}, tokens: redacted)';

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';
  static const String _expiresAtKey = 'expiresAt';
  static const String _refreshExpiresAtKey = 'refreshExpiresAt';
  static const String _operatorIdKey = 'operatorId';
  static const String _operatorNameKey = 'operatorName';

  static Object? _tryDecodeJson(String encoded) {
    try {
      return jsonDecode(encoded);
    } on FormatException {
      return null;
    }
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
