/// A Codex Bridge base URL that has already been accepted.
///
/// The type *is* the guard. [ServerUrl] has no public constructor, so the only
/// way to obtain one is [ServerUrl.parse] — nothing downstream (the probe, the
/// store, the screen) has to remember to validate a string before using it, and
/// no future call site can forget. `design-standards.md` §3: the invalid state
/// is unrepresentable rather than checked at each caller.
class ServerUrl {
  const ServerUrl._(this.value);

  /// Normalized absolute URL: lowercase host, explicit port only when it is not
  /// the scheme default, and no trailing slash on the base path.
  final Uri value;

  /// Parses [raw] into either an accepted [ServerUrl] or a named rejection.
  ///
  /// The result is a sealed type rather than a nullable [ServerUrl] because the
  /// issue requires rejections to be explicit: the caller has to render *why*
  /// the URL was refused, and a `null` cannot say.
  static ServerUrlParse parse(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ServerUrlRejected(ServerUrlRejection.empty);
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return const ServerUrlRejected(ServerUrlRejection.malformed);
    }
    if (!parsed.hasScheme) {
      return const ServerUrlRejected(ServerUrlRejection.notAbsolute);
    }
    if (parsed.scheme.toLowerCase() != _scheme) {
      return const ServerUrlRejected(ServerUrlRejection.insecureScheme);
    }
    if (parsed.host.isEmpty) {
      return const ServerUrlRejected(ServerUrlRejection.missingHost);
    }
    if (!_isValidHost(parsed.host)) {
      // `Uri` percent-encodes whatever it is given rather than refusing it, so
      // `https://gate way.example.com` parses cleanly into the host
      // `gate%20way.example.com`. Without this check a typo becomes a DNS
      // failure at test time and an opaque "unreachable" for the operator.
      return const ServerUrlRejected(ServerUrlRejection.invalidHost);
    }
    if (parsed.userInfo.isNotEmpty) {
      return const ServerUrlRejected(ServerUrlRejection.embeddedCredentials);
    }
    if (parsed.hasQuery || parsed.hasFragment) {
      return const ServerUrlRejected(ServerUrlRejection.queryOrFragment);
    }

    return ServerUrlAccepted(
      ServerUrl._(
        Uri(
          scheme: _scheme,
          host: parsed.host.toLowerCase(),
          port: parsed.hasPort ? parsed.port : null,
          path: _withoutTrailingSlashes(parsed.path),
        ),
      ),
    );
  }

  /// Absolute URL of a probe endpoint under this base.
  ///
  /// [endpointPath] is a contract path such as `/health`, so a gateway served
  /// under a reverse-proxy sub-path keeps that prefix.
  Uri endpoint(String endpointPath) =>
      value.replace(path: '${value.path}$endpointPath');

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      other is ServerUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;

  static const String _scheme = 'https';

  /// Hostname or IPv4 literal: letters, digits, dots and hyphens, never leading
  /// or trailing a separator.
  static final RegExp _hostPattern = RegExp(
    r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$',
  );

  /// IPv6 literal as `Uri` reports it — brackets already stripped.
  static final RegExp _ipv6HostPattern = RegExp(r'^[0-9A-Fa-f:.]+$');

  static bool _isValidHost(String host) =>
      _hostPattern.hasMatch(host) || _ipv6HostPattern.hasMatch(host);

  static String _withoutTrailingSlashes(String path) {
    int end = path.length;
    while (end > 0 && path[end - 1] == '/') {
      end--;
    }
    return path.substring(0, end);
  }
}

/// Why a string was refused as a server URL, with the text the operator reads.
///
/// The message lives on the reason so the screen cannot invent a different
/// wording for the same refusal, and so a test can assert the decision without
/// asserting a widget's copy.
enum ServerUrlRejection {
  empty('Enter the Codex Bridge server URL.'),
  malformed('This is not a valid URL.'),
  notAbsolute('Enter an absolute URL, starting with https://.'),
  // The app denies cleartext traffic for every build variant
  // (android/app/src/main/res/xml/network_security_config.xml), so an http://
  // server can never be reached. Refusing it here explains why; letting it
  // through would fail later as an opaque platform error.
  insecureScheme('Only https:// is accepted: this app refuses cleartext.'),
  missingHost('The URL names no host.'),
  invalidHost('The host is not a valid hostname or IP address.'),
  embeddedCredentials(
    'Remove the credentials from the URL; signing in is a separate step.',
  ),
  queryOrFragment('A server URL carries no query string and no fragment.');

  const ServerUrlRejection(this.message);

  /// Operator-facing explanation. Carries no input echo, so a pasted secret
  /// cannot reach a screen or a log through it.
  final String message;
}

/// Outcome of [ServerUrl.parse].
sealed class ServerUrlParse {
  const ServerUrlParse();
}

final class ServerUrlAccepted extends ServerUrlParse {
  const ServerUrlAccepted(this.url);

  final ServerUrl url;
}

final class ServerUrlRejected extends ServerUrlParse {
  const ServerUrlRejected(this.reason);

  final ServerUrlRejection reason;
}
