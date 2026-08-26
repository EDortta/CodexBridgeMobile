/// Redaction applied to every audit value before it is stored — issue #46's
/// "sensitive values are redacted", enforced at the store boundary
/// (`InMemoryAuditTrailRepository.record`) rather than trusted to each call
/// site.
///
/// Two layers, both deliberately dumb and testable:
///
/// 1. **Key-based:** a context key that names a credential
///    ([sensitiveKeyFragments]) has its value replaced whole. A key is the
///    call site declaring what the value is — when it says `token`, no
///    pattern-matching second opinion is needed.
/// 2. **Value-based:** a value that matches a *known* credential shape — a
///    JWT's three dot-separated base64url segments, an
///    `Authorization: Bearer …` fragment, or this app's own mock-session
///    token prefixes (`local-access-…`/`local-refresh-…`,
///    `mock_auth_gateway.dart`) — is replaced even under an innocent key.
///    This layer is defense in depth, **not** a guarantee: an opaque server
///    token with no recognizable shape (`http_auth_gateway.dart` accepts any
///    non-empty string) cannot be caught by pattern. The actual guarantees
///    are the key-based layer above and the call-site rule that context
///    carries flags and ids, never free text (council 2026-08-26, the
///    security lens, round 1).
///
/// Long values are truncated: this trail records that something happened,
/// not documents. A justification's full text lives in the feature's own
/// record (e.g. `DecisionAuditEvent.comment`), never here.
library;

/// Replacement written in place of a redacted value.
const String redactedPlaceholder = '[redacted]';

/// Case-insensitive fragments that mark a context key as holding a secret.
///
/// Deliberately over-broad — `auth` also hits `author`, and that is the
/// right trade: an over-redacted context value costs a little detail, an
/// under-redacted one stores a credential (council 2026-08-26, the security
/// lens: `authorization` alone did not match an `auth` or `jwt` key).
const List<String> sensitiveKeyFragments = <String>[
  'password',
  'passphrase',
  'secret',
  'token',
  'credential',
  'auth',
  'bearer',
  'jwt',
  'cookie',
  'apikey',
  'api_key',
  'api-key',
];

/// Longest value kept verbatim; anything longer is cut and marked.
const int maxAuditValueLength = 200;

/// Three base64url segments joined by dots — the shape of a JWT. Segment
/// minimums keep ordinary prose ("v1.2.3", "a.b.c") out.
final RegExp _jwtLike = RegExp(
  r'[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}',
);

/// An HTTP credential scheme followed by its value.
final RegExp _bearerLike = RegExp(
  r'\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}',
  caseSensitive: false,
);

/// This app's own mock-session tokens: `local-access-<iso8601>` /
/// `local-refresh-<iso8601>` (`MockAuthGateway`). The ISO-8601 timestamp
/// carries colons, which fall outside [_jwtLike]'s base64url class — so the
/// one token format this codebase is guaranteed to produce needs its own
/// pattern (council 2026-08-26, the security lens, round 1).
final RegExp _mockSessionTokenLike = RegExp(
  r'local-(access|refresh)-\S+',
  caseSensitive: false,
);

/// A credential passed as a URL/form parameter — `?access_token=…`,
/// `password=…` — the shape a server error message quoting a request URL
/// would carry it in (council 2026-08-26, the adversarial user, round 1).
final RegExp _paramSecretLike = RegExp(
  r'\b(access_token|refresh_token|token|password|secret|api_key|apikey)=[^&\s"]+',
  caseSensitive: false,
);

bool isSensitiveAuditKey(String key) {
  final String lower = key.toLowerCase();
  return sensitiveKeyFragments.any(lower.contains);
}

/// [value] with anything credential-shaped removed and length bounded.
///
/// Pure — same input, same output — so the policy is testable without a
/// store behind it (`design-standards.md` §1).
String redactAuditValue(String value) {
  String cleaned = value
      .replaceAll(_bearerLike, redactedPlaceholder)
      .replaceAll(_jwtLike, redactedPlaceholder)
      .replaceAll(_mockSessionTokenLike, redactedPlaceholder)
      .replaceAll(_paramSecretLike, redactedPlaceholder);
  if (cleaned.length > maxAuditValueLength) {
    cleaned = '${cleaned.substring(0, maxAuditValueLength)}… [truncated]';
  }
  return cleaned;
}

/// [context] with every sensitive value redacted.
Map<String, String> redactAuditContext(Map<String, String> context) {
  return <String, String>{
    for (final MapEntry<String, String> entry in context.entries)
      entry.key: isSensitiveAuditKey(entry.key)
          ? redactedPlaceholder
          : redactAuditValue(entry.value),
  };
}
