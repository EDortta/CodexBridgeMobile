import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/auth_gateway.dart';
import '../domain/session.dart';

/// Talks to the real Codex Bridge authentication endpoints
/// (`EDortta/CodexBridge` issue #4, `docs/api/codex-bridge.openapi.yaml`).
///
/// The one seam this class does not close itself: [AuthGateway.signIn] and
/// [AuthGateway.renew] carry no server parameter (there is no [Session] yet to
/// carry a [GatewayContext] with one, for `signIn` — that is the whole reason
/// auth is its own gateway rather than a method on some other repository). So
/// the server address arrives as [resolveServer] instead of an import: `data/`
/// in one feature must not reach into another feature's `domain/`
/// (`docs/architecture/state-architecture.md`), and the composition that knows
/// both — the selected server and the auth gateway — belongs in `lib/app/`,
/// same as [GatewayContext] itself.
///
/// Structured like [HttpLiveSessionRepository] and [HttpServerProbe]: a plain
/// `dart:io` [HttpClient] per call, certificate verification never disabled,
/// and every transport failure caught at the one boundary instead of leaking
/// past whichever call site forgot to guard it.
class HttpAuthGateway implements AuthGateway {
  const HttpAuthGateway(
    this.resolveServer,
    this._now, {
    this.timeout = const Duration(seconds: 10),
  });

  /// Resolves the selected Codex Bridge server, or `null` when none is
  /// selected. A callable rather than a `ServerConfigStore` so this file never
  /// imports `features/server/` — see the class doc.
  final Future<Uri?> Function() resolveServer;

  /// Reads the current instant, exactly like [MockAuthGateway]'s injected
  /// clock: `expiresIn` in the response is seconds-from-now, and turning that
  /// into an absolute [Session.expiresAt] is a decision this class makes, so
  /// it is made against a clock a test can fix (`design-standards.md` §2).
  final DateTime Function() _now;

  /// Applied to the connection, to each request and to reading each body —
  /// the same discipline [HttpServerProbe] applies to its own probes, for the
  /// same reason: a server that accepts a socket and stalls must not hang the
  /// sign-in screen.
  final Duration timeout;

  static const String _signInPath = '/api/v1/auth/sign-in';
  static const String _refreshPath = '/api/v1/auth/refresh';
  static const String _revokePath = '/api/v1/auth/revoke';
  static const String _mePath = '/api/v1/auth/me';

  @override
  Future<AuthOutcome> signIn({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const AuthDenied(AuthFailure.missingCredential);
    }

    final Uri? server = await resolveServer();
    if (server == null) {
      // No server selected: there is nothing to sign in against. `unreachable`
      // is the closest of the four `AuthFailure` values — the operator's fix
      // ("check the connection") also covers "select a server first", and
      // `AuthGateway` promises exactly these four, not a fifth invented here.
      return const AuthDenied(AuthFailure.unreachable);
    }

    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final _JsonResponse response = await _postJson(
        client,
        _endpoint(server, _signInPath),
        <String, Object?>{'username': username, 'password': password},
      );

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.unprocessableEntity) {
        return const AuthDenied(AuthFailure.rejectedCredential);
      }
      if (response.statusCode != HttpStatus.ok) {
        return const AuthDenied(AuthFailure.unreachable);
      }

      final _AuthTokens? tokens = _AuthTokens.tryParse(response.body);
      if (tokens == null) {
        return const AuthDenied(AuthFailure.unreachable);
      }

      // Sign-in and refresh answer with the grant, never the identity behind
      // it — `/auth/me` is the only endpoint that resolves one. Skipping this
      // call and inventing `operatorId` from the username the operator typed
      // would violate what `Session.operatorId` promises: "never taken from
      // anything the client supplied" (`session.dart`).
      final _Actor? actor = await _me(client, server, tokens.accessToken);
      if (actor == null) {
        // The grant now exists server-side, but this device never learned
        // whose it is and cannot show a session it cannot name. Reported as
        // refused rather than granted; the orphaned grant is left to expire on
        // its own short access-token TTL — an accepted residual risk of the
        // same shape the gateway's own `/auth/revoke` docstring already
        // accepts for a replayed refresh token.
        return const AuthDenied(AuthFailure.unreachable);
      }

      final DateTime now = _now();
      return AuthGranted(
        Session(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: now.add(Duration(seconds: tokens.expiresInSeconds)),
          refreshExpiresAt: tokens.refreshExpiresAt,
          operatorId: actor.id,
          operatorName: actor.name,
        ),
      );
    } on Object {
      return const AuthDenied(AuthFailure.unreachable);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AuthOutcome> renew(Session session) async {
    final Uri? server = await resolveServer();
    if (server == null) {
      return const AuthDenied(AuthFailure.unreachable);
    }

    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final _JsonResponse response = await _postJson(
        client,
        _endpoint(server, _refreshPath),
        <String, Object?>{'refreshToken': session.refreshToken},
      );

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.unprocessableEntity) {
        // The refresh token was rejected, reused, or belongs to a grant the
        // server already ended — every one of those is "this device can no
        // longer renew", the same meaning `MockAuthGateway` gives a closed
        // refresh window.
        return const AuthDenied(AuthFailure.sessionNoLongerRenewable);
      }
      if (response.statusCode != HttpStatus.ok) {
        return const AuthDenied(AuthFailure.unreachable);
      }

      final _AuthTokens? tokens = _AuthTokens.tryParse(response.body);
      if (tokens == null) {
        return const AuthDenied(AuthFailure.unreachable);
      }

      final DateTime now = _now();
      return AuthGranted(
        Session(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          expiresAt: now.add(Duration(seconds: tokens.expiresInSeconds)),
          refreshExpiresAt: tokens.refreshExpiresAt,
          // Carried forward rather than re-read from `/auth/me`: a rotation is
          // the same actor renewing the same grant, and a second round trip
          // here would double the network cost of every renewal for a field
          // that cannot have changed shape.
          operatorId: session.operatorId,
          operatorName: session.operatorName,
        ),
      );
    } on Object {
      return const AuthDenied(AuthFailure.unreachable);
    } finally {
      client.close(force: true);
    }
  }

  /// Ends [session]'s grant on the server, now rather than at its natural
  /// expiry, by calling `POST /api/v1/auth/revoke`.
  ///
  /// Called by `SessionController.signOut` alongside the local keystore clear
  /// (`#53`). That method's sign-out path is the most race-hardened part of
  /// this feature (`design-standards.md` §3 — three separate generation
  /// checks exist there solely to stop a renewal from resurrecting a session
  /// the operator just removed); this call sits entirely inside the network
  /// leg of that path and never itself writes state, so none of those checks
  /// change shape here.
  ///
  /// Returns whether the server confirmed the revocation. Never throws: a
  /// revoke that fails is not worth blocking a local sign-out over, so the
  /// caller treats the return value as advisory, not as a signal to retry or
  /// escalate.
  @override
  Future<bool> revoke(Session session) async {
    final Uri? server = await resolveServer();
    if (server == null) {
      return false;
    }

    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .postUrl(_endpoint(server, _revokePath))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${session.accessToken}',
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode(<String, Object?>{'refreshToken': session.refreshToken}),
        ),
      );
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// The actor behind [accessToken], from `GET /api/v1/auth/me` — the only
  /// endpoint that resolves a token to an identity. Returns `null` on any
  /// failure, transport or shape alike: the caller decides what that means.
  Future<_Actor?> _me(HttpClient client, Uri server, String accessToken) async {
    try {
      final HttpClientRequest request = await client
          .getUrl(_endpoint(server, _mePath))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final String body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      return _Actor.tryParse(body);
    } on Object {
      return null;
    }
  }

  Future<_JsonResponse> _postJson(
    HttpClient client,
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final HttpClientRequest request = await client
        .postUrl(uri)
        .timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.add(utf8.encode(jsonEncode(body)));
    final HttpClientResponse response = await request.close().timeout(timeout);
    final String raw = await utf8.decoder
        .bind(response)
        .join()
        .timeout(timeout);
    return _JsonResponse(statusCode: response.statusCode, body: raw);
  }

  static Uri _endpoint(Uri server, String path) =>
      server.replace(path: '${server.path}$path');
}

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// The `AuthTokens` shape from `docs/api/codex-bridge.openapi.yaml`: what
/// both sign-in and refresh return on success.
class _AuthTokens {
  const _AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;

  /// Seconds until the access token expires, counted from the response.
  /// Preferred over the paired absolute timestamp for exactly the reason the
  /// contract's own description names: it is the only form that survives a
  /// device whose clock is wrong.
  final int expiresInSeconds;

  /// The grant's absolute expiry. Read as an instant, not as an offset — this
  /// is the outer bound of the session, not a value to schedule against.
  final DateTime refreshExpiresAt;

  static _AuthTokens? tryParse(String raw) {
    final Map<String, Object?>? decoded = _decodeObject(raw);
    if (decoded == null) {
      return null;
    }
    final String? accessToken = _string(decoded['accessToken']);
    final String? refreshToken = _string(decoded['refreshToken']);
    final int? expiresIn = decoded['expiresIn'] is int
        ? decoded['expiresIn']! as int
        : null;
    final DateTime? refreshExpiresAt = _instant(
      decoded['refreshTokenExpiresAt'],
    );
    if (accessToken == null ||
        refreshToken == null ||
        expiresIn == null ||
        refreshExpiresAt == null) {
      return null;
    }
    return _AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresIn,
      refreshExpiresAt: refreshExpiresAt,
    );
  }
}

/// The actor half of `GET /api/v1/auth/me`'s response: just enough to fill
/// [Session.operatorId] and [Session.operatorName].
class _Actor {
  const _Actor({required this.id, required this.name});

  final String id;
  final String name;

  static _Actor? tryParse(String raw) {
    final Map<String, Object?>? decoded = _decodeObject(raw);
    if (decoded == null) {
      return null;
    }
    final Object? actor = decoded['actor'];
    if (actor is! Map<String, Object?>) {
      return null;
    }
    final String? id = _string(actor['id']);
    if (id == null) {
      return null;
    }
    // `displayName` is in the contract's schema but the current server build
    // does not send it (`gateway/app/api/routes/auth.py`); `email` is "omitted
    // unless the caller is authorized to see it" and may be absent too. `id`
    // is the one field the contract requires, so it is the floor.
    final String name =
        _string(actor['displayName']) ?? _string(actor['email']) ?? id;
    return _Actor(id: id, name: name);
  }
}

Map<String, Object?>? _decodeObject(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  return decoded is Map<String, Object?> ? decoded : null;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _instant(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
