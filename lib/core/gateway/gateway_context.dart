/// The server and credential an authenticated feature needs to call the
/// Codex Bridge gateway, resolved by composition — see
/// `gateway_context_provider.dart`.
class GatewayContext {
  const GatewayContext({required this.server, required this.accessToken});

  final Uri server;
  final String accessToken;
}
