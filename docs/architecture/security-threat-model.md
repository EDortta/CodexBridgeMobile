# Security threat model and baseline

- work_id: WK-20260821-gh-45-mobile-threat-model-and-security-baseline
- date: 2026-08-21
- public issue: https://github.com/EDortta/CodexBridgeMobile/issues/45
- parent epic: https://github.com/EDortta/CodexBridgeMobile/issues/14 — Segurança, privacidade e auditoria

Cross-cutting, like `state-architecture.md` and `navigation.md` — read this before
touching authentication, session storage, the network client, local secure
storage, or (once built) file access, APK delivery, or notifications. This is not
tied to a `docs/issues/phase-N/` epic because Epic #14 is transversal by its own
definition ("inicia após a Epic #1 e acompanha todas as demais") rather than a
sequential phase; see `docs/issues/epic-14/README.md` for its issue tracking.

## Method

Grounded in the code as it exists on `development` at the time of writing, not a
generic mobile-OWASP template. Every asset, boundary and abuse case below cites
the file that backs it. Two features carry real secrets today —
authentication/session (#21, #22) and server selection (#21) — everything else
(decisions, missions, projects, artifacts, activity) is still a local mock with
no live backend, and several epic #14 surfaces (APK install, SAF, notifications,
audit trail, biometric gate) have no code yet. Those are documented as **baseline
requirements** for the issue that will build them, not as findings against
code that does not exist.

## Assets

| Asset | Where it lives | Sensitivity |
|---|---|---|
| Access token, refresh token | `Session` (`lib/features/auth/domain/session.dart`), Keystore-backed via `SecureSessionStore` | High — bearer credential for every gateway call |
| Selected gateway server URL | `SecureServerConfigStore` (`lib/features/server/data/secure_server_config_store.dart`) | Low on its own, but pins the trust boundary in §Network below |
| Operator identity (`operatorId`, `operatorName`) | Inside `Session`, server-resolved, never client-chosen (`session.dart:53-58`) | Medium — identifies the account this device is linked to |
| Project favorites | `SecureProjectFavoritesStore` (`lib/features/projects/data/secure_project_favorites_store.dart`) | Low |
| Decisions, missions, sessions, logs, artifacts fetched from the gateway | In-memory only today (mock repositories); real data once CodexBridge's APIs land | Medium–High depending on project — risk/impact summaries, blocked reasons and live-session logs can carry operational and business detail |
| (Future) user-selected files read via SAF — #39 | Not built | Depends entirely on what the operator picks; treat as high until classified |
| (Future) APK artifacts installed via #37/#38 | Not built | High — code execution on the operator's device |
| (Future) audit trail records — #46 | Not built | Medium–High — the record of what a sensitive operation did |

## Actors

- **Operator** — the device owner, the only actor the product is built for.
- **Attacker with physical access to an unlocked or compromised device** —
  the threat `Session`'s own doc comment names explicitly ("a stolen device
  would hold a session forever", `session.dart:51`).
- **Network attacker** on the operator's Wi-Fi/mobile network, or a
  DNS-hijacked path to `frida.inovacaosistemas.com.br`.
- **Another app on the same device** (side-loaded or compromised) —
  clipboard, intent, and accessibility-service abuse are in scope once the
  app exposes intent filters, install flows or SAF pickers; today's manifest
  exposes none of those.
- **Distributor of a trojanized "update"** — see R1 below; this is a real
  actor class only because of how the app is currently signed, not a
  hypothetical.
- **The Codex Bridge gateway operator/CI** — a supply-chain actor for
  whatever the gateway serves as "the app's own APK metadata" once #37 exists.

## Trust boundaries

1. **Operator ↔ device UI.** Device unlock is the only local gate today; no
   in-app biometric/PIN re-check exists before a sensitive action (Epic #14
   lists this as unbuilt — see R11).
2. **App ↔ Android Keystore.** `SecureKeyValueStore` / `FlutterSecureKeyValueStore`
   (`lib/core/storage/`) is the only boundary between "in memory" and "on
   disk". Every write crossing it is deliberately narrow — three methods,
   no policy (`secure_key_value_store.dart:1-13`).
3. **App ↔ Codex Bridge gateway (network).** TLS-only by policy
   (`android/app/src/main/res/xml/network_security_config.xml`): cleartext
   denied globally, one domain explicitly allow-listed. Bearer token carried
   in the `Authorization` header, never in a URL or query string
   (`http_live_session_repository.dart`, consistent with
   `security-standards.md` §3).
4. **App ↔ Android OS install flow** (future, #37/#38) — not yet crossed;
   no `REQUEST_INSTALL_PACKAGES` permission declared, no installer intent
   code exists. Baseline requirements in R8.
5. **App ↔ Storage Access Framework** (future, #39) — not yet crossed.
   Baseline requirements in R9.
6. **Build ↔ distribution** (signing, CI). CI (`​.github/workflows/flutter-ci.yml`)
   pins third-party actions by commit SHA — good practice already in place —
   but the release APK it builds is debug-signed (R1, critical).

## Attack surfaces and abuse cases

Ordered by priority. Each entry states current status and an owner or
follow-up per the issue's acceptance criteria.

### R1 — CRITICAL — release build is signed with the debug keystore

`android/app/build.gradle.kts`:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

The Android SDK's debug keystore (`debug.keystore`) has a fixed alias
(`androiddebugkey`), a fixed password (`android`/`android`), and a fixed
certificate DN (`CN=Android Debug,O=Android,C=US`) by convention — but the
RSA key pair itself is **not** a shared secret: `flutter`/`gradle` generate
it locally, once, the first time a given machine builds a debug variant, so
different machines normally end up with different key material under that
same conventional alias/DN. This repo does not check in a `debug.keystore`
(confirmed gitignored; none present in the tree), so there is no shared-file
mechanism today that hands every developer machine the same key.

The risk is narrower than "any Android developer's debug key works," but
still Critical: whichever machine (a developer's or CI's) generated **this
project's own** `debug.keystore` holds the one key that actually matters,
because that is the file `android/app/build.gradle.kts` uses to sign every
release build. If that specific file leaks — committed by accident, copied
off a compromised CI runner or developer machine, shared over chat — anyone
who obtains it can sign an APK with the exact same certificate this build
uses. Because Android treats "same package ID + same signing certificate" as
a trusted in-place upgrade, an attacker who gets that trojanized APK onto a
device that already installed a debug-signed build (this is CI's own
`flutter build apk --release` output today) can overwrite the legitimate app
with one of their own choosing, silently, no signature warning shown.

- **Abuse path:** this project's `debug.keystore` (whichever machine
  produced the one CI/release builds currently sign with) leaks, an attacker
  signs an APK with it under the same `applicationId`
  (`com.edortta.codexbridge.mobile`), distributes it (sideload, phishing
  link, malicious MDM push) → Android accepts it as an update → operator's
  next credential entry goes to attacker-controlled code.
- **Mitigation:** generate a dedicated release keystore, keep it out of the
  repository (`security-standards.md` §1 — key material gitignored,
  `chmod 600`), wire it through Gradle properties read from the environment,
  never a checked-in default. Not built here — no release signing issue
  exists yet.
- **Owner/follow-up:** none of #16–#47 currently covers this. **Recommend
  the operator file a new issue** (Epic #10 — Entrega Android e instalação
  de APK, or Epic #14) before this app is ever distributed outside a
  developer's own machine. Flagging it here satisfies "each critical risk
  has an owner or follow-up issue" — the issue itself is not filed by this
  PR (docs-only scope; filing GitHub issues is the operator's call).

### R2 — HIGH — mock auth has no release gate

`authGatewayProvider` (`lib/features/auth/presentation/auth_providers.dart:27-29`)
returns `MockAuthGateway` unconditionally — including in `flutter build apk
--release`, which CI builds successfully today. `MockAuthGateway.signIn`
(`mock_auth_gateway.dart:40-50`) grants a session for any non-blank string.

`security-standards.md` §4: *"Mock/demo auth is gated to DEV and excluded
from production bundles."* That gate does not exist. It is not yet
exploitable against real privilege — the CodexBridge authentication contract
is still unwritten (CodexBridge #4) and the mock's tokens are accepted by no
real server — but the gap is structural: **when the real `HttpAuthGateway`
lands, if the swap does not also add a `kReleaseMode` (or build-flavor)
gate, a release APK could ship with a bypass reachable by anyone who reads
the code.** This exact question was raised and left open in a council round
on 2026-08-14 (`docs/napkin-lessons.md`, "the adversarial user") and never
resolved.

- **Mitigation (baseline requirement):** the issue that wires the real
  gateway auth (CodexBridge #4 integration — not yet filed on this side)
  must gate `authGatewayProvider` on `kReleaseMode` (or an explicit build
  flavor), refusing to compile the mock into a release artifact, per
  `security-standards.md` §4.
- **Owner/follow-up:** the future CodexBridge-#4-integration issue. This
  doc is what makes that requirement explicit and traceable so it is not
  rediscovered at review time.

### R3 — MEDIUM — session lifecycle trusts the device clock

Every lifecycle decision (`Session.isExpiredAt`, `isRenewableAt`,
`needsRenewalAt`, `lifecycleAt`) reads `sessionClockProvider`
(`DateTime.timestamp`), which an attacker with physical device access can
roll backward to revive a session past its refresh window
(`docs/napkin-lessons.md`, "the adversarial user", 2026-08-14 — flagged, not
reproduced as a wrong outcome because no request yet presents the token to a
real server).

- **Mitigation:** the client lifecycle must stay UX-only (disabling
  buttons, prompting renewal) — the gateway is the authoritative expiry
  check on every request, independent of the device's clock. This is an
  assumption on the CodexBridge backend contract, not something fixable
  client-side.
- **Owner/follow-up:** external — CodexBridge gateway's auth verification.
  Recorded here so the assumption is explicit when that contract is written.

### R4 — MEDIUM — pending-removal marker fails open where the session read fails closed

`SecureSessionStore._hasPendingRemoval` (`secure_session_store.dart:48-58`)
catches `Exception` and returns `false`; `_read` (line 74-80) catches
`Exception` and returns `null`. On a keystore that can read the session key
but throws on the marker key specifically, a sign-out that failed to delete
the session (and set the marker) could be silently un-suppressed on the next
launch — the session reads back as active even though a removal was
attempted and refused. Open question in `docs/napkin-lessons.md` since
2026-08-14, unresolved, pre-existing in shipped #22 code.

- **Mitigation:** either both reads fail closed (marker-unreadable ⇒ treat
  as "removal may be pending", not "no marker") or the asymmetry gets an
  explicit written justification.
- **Owner/follow-up:** small hardening issue against `SecureSessionStore`,
  not yet filed. **Recommend the operator file it** — it is a narrow,
  well-scoped fix (a few lines, existing test file to extend), not
  appropriate to bundle into this docs-only delivery.

### R5 — MEDIUM — no certificate/public-key pinning

`network_security_config.xml` denies cleartext globally and restricts the
gateway to one explicit domain, but trusts the full system CA store
(`<certificates src="system" />`). A device with an attacker- or
MDM-installed root CA can still terminate TLS in the middle. This is
standard practice for most apps and is not a defect on its own, but it is a
product/ops trade-off worth an explicit decision once the app carries real
operator credentials against a live backend rather than a mock.

- **Mitigation:** consider certificate or public-key pinning for the
  gateway domain once CodexBridge auth is real; until then, the risk is
  accepted at the "trust the OS" level most Android apps operate at.
- **Owner/follow-up:** operator decision, not a code change — recorded here
  so it is not silently assumed away.

### R6 — LOW/MEDIUM — no explicit backup exclusion for local secrets

`AndroidManifest.xml` declares no `android:allowBackup` (defaults to `true`)
and no `dataExtractionRules`/`fullBackupContent` (Android 12+). Android
Keystore-backed key material itself is not exportable through backup, but
the `flutter_secure_storage` ciphertext blob and any future unencrypted
local cache (Epic #12 — Sincronização e operação offline, not started) could
be captured by `adb backup` on a debuggable or rooted device.

- **Mitigation:** declare `android:allowBackup="false"` (or a
  `dataExtractionRules` excluding the secure-storage-backed preference file)
  before Epic #12 introduces any local cache that is not itself
  Keystore-backed.
- **Owner/follow-up:** bundle into whichever issue introduces local disk
  cache (Epic #12), or a small standalone hardening issue now. Not applied
  in this PR — the issue's acceptance criterion asks that "local data
  exposure" be *covered* by the threat model, not that every manifest flag
  be flipped ahead of the feature that needs it; today's actual on-disk
  footprint is exactly the three Keystore-backed keys named in §Assets and
  nothing in plaintext.

### R7 — LOW — inconsistent request timeouts

`HttpServerProbe` (`lib/features/server/data/http_server_probe.dart`)
deliberately bounds every connection, request and body read
(`timeout` field, `maxProbeBodyBytes` cap) because it is a probe against a
host the operator just typed. `HttpLiveSessionRepository`
(`lib/features/missions/data/http_live_session_repository.dart`) does not
apply an equivalent timeout to most of its calls — a stalled or malicious
gateway response can hang a screen indefinitely. Client-side availability
issue, not a data-exposure one.

- **Mitigation:** apply the same bounded-read discipline `HttpServerProbe`
  already uses.
- **Owner/follow-up:** hardening item for whoever next touches
  `HttpLiveSessionRepository` (shipped under #32).

## Baseline security requirements for unbuilt epic #14 / adjacent surfaces

These are not findings against existing code — the code does not exist yet.
They are the contract the listed issues must be built against, per this
issue's own title ("...and security baseline").

### R8 — APK install flow (#37 "APK metadata and trust verification", #38 "explicit Android APK installation flow")

- `REQUEST_INSTALL_PACKAGES` is requested narrowly and only at the moment
  the operator explicitly initiates an install — never declared as an
  always-on manifest permission granted at install time, never triggered
  automatically.
- The APK's signing certificate / SHA-256 is verified against a value
  obtained over the already-authenticated gateway channel (the same
  `Authorization: Bearer` session this doc's §Trust boundaries #3 covers) —
  never a value embedded in the same download being verified, and never
  trust-on-first-use.
- The install intent uses a `FileProvider` content URI, never a `file://`
  URI (blocked by the OS on modern Android anyway, but the point is to fail
  by design, not by platform accident).
- Every install attempt — offered, accepted, refused, failed — is an audit
  event (#46), matching the epic's own "trilha de auditoria para... operações
  sensíveis" criterion.

### R9 — Storage Access Framework (#39)

- Reads use `ACTION_OPEN_DOCUMENT` (user-explicit, per-file grant) only.
  `MANAGE_EXTERNAL_STORAGE` or any legacy broad storage permission is out of
  scope — `docs/limits.md` already prohibits unrestricted device access.
- File content is untrusted input: MIME type and size are validated before
  parsing (`security-standards.md` §9's path-confinement instinct extended
  to SAF `Uri` grants — a content URI is not a filesystem path, but the same
  "never trust what the caller handed you" applies), and nothing selected
  through SAF is executed or auto-rendered as active content (no unsandboxed
  WebView on a user file).
- Grant persistence (`takePersistableUriPermission`) is scoped to exactly
  the files the operator selected, and is released when the app no longer
  needs it — not held indefinitely "just in case".

### R10 — Notifications (#43 "internal notification center and deep links", #44 "notification preferences and privacy controls")

- Lock-screen/shade visibility defaults to a redacted summary
  (`NotificationCompat.VISIBILITY_PRIVATE` or generic text) for anything
  carrying decision/mission content with business or risk detail; full
  content renders only after the device is unlocked and the app is open —
  the same instinct `security-standards.md` §2 applies to logs, extended to
  a surface that is itself semi-public (visible to anyone glancing at a
  locked screen).
- Deep links into the app validate the target before navigating (no route
  that trusts an external caller's parameters as already-authorized).

### R11 — Epic #14 checklist items with no filed issue yet

Epic #14's own scope (`gh issue view 14`) lists items that satisfy the
"each critical risk has an owner or follow-up issue" acceptance criterion
only if they get an owner. As of this writing, `#45`/`#46`/`#47` are the
only issues filed against Epic #14 (`#47` covers accessibility, tracked
separately and out of this doc's scope). These three checklist items have
**no GitHub issue**:

- "Proteger ações críticas com biometria opcional" — no in-app biometric/PIN
  re-check exists before any sensitive action (approve/reject a decision,
  cancel a mission, sign out). Trust boundary #1 above depends on this.
- "Aplicar minimização de dados locais" — no explicit retention/minimization
  policy is written anywhere for what the app caches once Epic #12's offline
  store lands.
- "Permitir limpeza segura de dados e revogação remota" — sign-out clears
  only the local session key (`SecureSessionStore.clearSession`); there is
  no remote-revocation call to the gateway, and no "wipe this device's
  data" operator action.

**Recommend the operator file three follow-up issues** (or fold them into
existing #46/#39 scopes where they naturally overlap) so these have an
explicit owner rather than staying implicit epic prose. Not filed by this
PR — filing GitHub issues is the operator's call, and this doc's job is to
surface the gap, not decide the epic's issue list unilaterally.

## Android permissions and local data exposure (acceptance-criterion summary)

**Permissions.** `android/app/src/main/AndroidManifest.xml` declares exactly
one runtime-relevant permission: `android.permission.INTERNET`, required to
reach the gateway (comment at the top of the file records why it was
missing from a release build once before — a manifest-merge regression,
`docs/issues/phase-0/RESUME.md`, council 2026-08-06). The debug/profile
variants add nothing beyond the same `INTERNET` permission for the Flutter
tool's own hot-reload channel; CI's `flutter-ci.yml` explicitly builds and
asserts the **release** manifest to catch a variant-only permission gap
before it reaches an operator's device. The one `<queries>` block declares
`ACTION_PROCESS_TEXT` visibility for Flutter's own text-selection toolbar —
not attacker-influenced. No location, camera, contacts, SMS, storage,
biometric, notification, or install permission is requested anywhere today.
This matches `docs/limits.md`'s "device permissions must be granular and
feature-justified" — there is currently nothing to prune.

**Local data exposure.** Everything persisted to disk today goes through
`SecureKeyValueStore` → Android Keystore-backed encrypted storage. Three
keys exist: the session (`SecureSessionStore.sessionKey` +
`_pendingRemovalKey`), the selected server
(`SecureServerConfigStore.selectedServerKey`), and project favorites
(`SecureProjectFavoritesStore`). No unencrypted local database, cache, or
file exists — decisions, missions, sessions, projects and artifacts are
all in-memory mock data with no disk footprint. The one open gap is R6
(no explicit backup exclusion) — low severity today precisely because there
is nothing outside the Keystore to expose, but worth closing before Epic
#12 adds a real local cache.

## Residual risks accepted as-is

- R3 and R5 are accepted at "the gateway/OS is the authority" level — this
  is standard for a mobile client and not something this repository can
  unilaterally harden further without a backend or product decision.
- R7 is a client-side availability gap, not a confidentiality/integrity one.

## When to revisit this document

- Before any release build leaves a developer's machine (R1 must be closed
  first).
- When CodexBridge's real authentication contract (CodexBridge #4) lands —
  re-check R2 and R3 against the real implementation.
- Before #37/#38 (APK install) or #39 (SAF) start implementation — re-read
  R8/R9 as their acceptance criteria.
- Before #46 (audit trail) starts — R8/R9/R10 name what it needs to log.
- Whenever a new Android permission is added — re-check the "Android
  permissions" summary above stays accurate.
