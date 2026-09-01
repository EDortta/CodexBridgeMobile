import 'package:codex_bridge_mobile/core/audit/audit_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// #46: "sensitive values are redacted" — the pure policy, tested without a
/// store behind it.
void main() {
  group('isSensitiveAuditKey', () {
    test('matches credential-naming keys case-insensitively', () {
      expect(isSensitiveAuditKey('password'), isTrue);
      expect(isSensitiveAuditKey('accessToken'), isTrue);
      expect(isSensitiveAuditKey('Authorization'), isTrue);
      expect(isSensitiveAuditKey('client_secret'), isTrue);
      expect(isSensitiveAuditKey('Api-Key'), isTrue);
      expect(isSensitiveAuditKey('passphrase'), isTrue);
    });

    test('leaves ordinary keys alone', () {
      expect(isSensitiveAuditKey('commentProvided'), isFalse);
      expect(isSensitiveAuditKey('reasonProvided'), isFalse);
      expect(isSensitiveAuditKey('sessionId'), isFalse);
    });

    test('short credential fragments match too — auth, bearer, jwt', () {
      // council 2026-08-26, the security lens: `authorization` alone did
      // not cover an `auth` or `jwt` key.
      expect(isSensitiveAuditKey('auth'), isTrue);
      expect(isSensitiveAuditKey('bearerValue'), isTrue);
      expect(isSensitiveAuditKey('jwt'), isTrue);
    });
  });

  group('redactAuditValue', () {
    test('replaces a JWT-shaped value even under an innocent name', () {
      const String jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJvcGVyYXRvciJ9.c2lnbmF0dXJlLXNlZ21lbnQ';
      expect(redactAuditValue('failed with $jwt attached'),
          'failed with $redactedPlaceholder attached');
    });

    test('replaces a Bearer credential fragment', () {
      expect(
        redactAuditValue('request sent Authorization: Bearer abc12345token'),
        contains(redactedPlaceholder),
      );
      expect(
        redactAuditValue('request sent Authorization: Bearer abc12345token'),
        isNot(contains('abc12345token')),
      );
    });

    test('keeps ordinary operator-facing text unchanged', () {
      const String message = 'No session found with id "s-9".';
      expect(redactAuditValue(message), message);
    });

    test("replaces this app's own mock-session token format", () {
      // council 2026-08-26, the security lens: `local-access-<iso8601>`
      // carries colons, which the JWT pattern's base64url class misses.
      const String token = 'local-access-2026-08-26T15:00:00.000Z';
      expect(redactAuditValue('renewal failed for $token'),
          'renewal failed for $redactedPlaceholder');
      expect(
        redactAuditValue('local-refresh-2026-08-27T15:00:00.000Z rejected'),
        '$redactedPlaceholder rejected',
      );
    });

    test('replaces a credential passed as a URL parameter', () {
      final String redacted = redactAuditValue(
        'GET /session?access_token=abc123&state=x refused',
      );
      expect(redacted, isNot(contains('abc123')));
      expect(redactAuditValue('password=hunter2 rejected'),
          '$redactedPlaceholder rejected');
    });

    test('does not mistake a version string for a JWT', () {
      expect(redactAuditValue('upgraded v1.2.3 to v1.2.4'),
          'upgraded v1.2.3 to v1.2.4');
    });

    test('truncates values past the cap and says so', () {
      final String long = 'x' * (maxAuditValueLength + 50);
      final String redacted = redactAuditValue(long);
      expect(redacted, endsWith('… [truncated]'));
      expect(redacted.length, lessThan(long.length));
    });
  });

  group('redactAuditContext', () {
    test('redacts by key, redacts by value shape, passes the rest', () {
      final Map<String, String> redacted = redactAuditContext(<String, String>{
        'accessToken': 'anything at all',
        'note': 'bearer aaaabbbbccccdddd went out',
        'commentProvided': 'true',
      });
      expect(redacted['accessToken'], redactedPlaceholder);
      expect(redacted['note'], isNot(contains('aaaabbbbccccdddd')));
      expect(redacted['commentProvided'], 'true');
    });
  });
}
