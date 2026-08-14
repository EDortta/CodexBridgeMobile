/// What the connection test reports about the server's TLS certificate.
///
/// Owned by this side of the boundary rather than being `X509Certificate`
/// itself (`design-standards.md` §2): the screen and its tests never touch
/// `dart:io`, and a change of HTTP client changes one adapter.
///
/// It carries only fields an operator can act on. The public key, the DER bytes
/// and the serial are deliberately absent — they are noise on a phone screen,
/// and every field kept here is a field that could end up in a log.
class ServerCertificate {
  const ServerCertificate({
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
  });

  /// Distinguished name of the certificate's subject.
  final String subject;

  /// Distinguished name of the issuing authority.
  final String issuer;

  final DateTime validFrom;

  final DateTime validTo;
}
