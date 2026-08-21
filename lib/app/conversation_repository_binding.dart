import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/conversations/data/http_conversation_repository.dart';
import '../features/conversations/data/mock_conversation_repository.dart';
import '../features/conversations/domain/conversation_repository.dart';
import '../features/conversations/presentation/conversation_providers.dart';

/// The real [conversationRepositoryProvider]: [HttpConversationRepository]
/// against the real Codex Bridge gateway in a release build,
/// [MockConversationRepository] otherwise — the identical switch
/// [authGatewayBinding] makes for `authGatewayProvider`, composed here for
/// the same reason: `lib/app/` is the one layer allowed to import a
/// feature's `presentation/` layer to override its provider
/// (`docs/architecture/state-architecture.md`).
///
/// Unlike [authGatewayBinding], this repository needs no `resolveServer`
/// callback of its own: every [ConversationRepository] method already takes
/// `server`/`accessToken` per call (the same convention
/// `liveSessionRepositoryProvider` uses), resolved from
/// `gatewayContextProvider` by the feature's own providers.
final Override conversationRepositoryBinding = conversationRepositoryProvider
    .overrideWith((Ref ref) => resolveConversationRepository(kReleaseMode));

/// The decision behind [conversationRepositoryBinding], pulled out so both
/// branches run under a plain unit test instead of only ever exercising the
/// one `kReleaseMode` compiles to in any given test process
/// (`design-standards.md` §1).
ConversationRepository resolveConversationRepository(bool releaseMode) {
  if (releaseMode) {
    return const HttpConversationRepository();
  }
  return MockConversationRepository();
}
