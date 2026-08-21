import 'dart:math';

/// A client-generated key for `Idempotency-Key`, in the shape
/// `docs/api/codex-bridge.openapi.yaml`'s `IdempotencyKey` parameter expects:
/// an opaque, sufficiently-random token, not necessarily RFC 4122 — the
/// server only ever compares it byte-for-byte against what a previous
/// request with the same key, actor and endpoint stored, never parses it.
///
/// This app has no existing id-generator to reuse for consistency (searched
/// at the time this was written — no `uuid` dependency, no other
/// client-generated identifier anywhere in `lib/`), so this is a from-scratch
/// UUID v4 built on [Random.secure] rather than a new package dependency for
/// one sixteen-byte value. `Random.secure()` is seeded from the platform's
/// CSPRNG, not `Random()`'s weaker default — an idempotency key doubles as a
/// dedup token servers key on, so a predictable one is a scoped choice worth
/// naming, not just a convenience.
///
/// Callers that need retry-safe idempotency (the actual point of the header)
/// must generate this once per logical action and pass the same value on
/// every retry of that action — calling this again on retry produces a
/// fresh key and defeats the purpose.
String generateIdempotencyKey() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // Version 4, variant 1 — cosmetic (nothing on the server parses the UUID
  // structure) but makes this indistinguishable from any other UUID v4 in a
  // log line, which is worth the two bit-twiddles.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
