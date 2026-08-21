import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/gateway/gateway_context.dart';
import '../../../core/gateway/gateway_context_provider.dart';
import '../data/mock_conversation_repository.dart';
import '../domain/conversation.dart';
import '../domain/conversation_page.dart';
import '../domain/conversation_repository.dart';

/// The real implementation is wired in as an override by
/// `lib/app/conversation_repository_binding.dart` — the same
/// release-vs-mock switch `authGatewayProvider` uses. This default keeps
/// widget tests and UI work that never installs that override on the mock.
final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((Ref ref) => MockConversationRepository());

/// The first page of conversations the caller may see, newest-created first.
///
/// Only the first page: nothing in this feature's UI paginates yet
/// ([ConversationsPage.hasMore]/`nextCursor` are read by
/// [HttpConversationRepository]'s tests but not consumed here) — a known,
/// scoped gap rather than a silent one.
final FutureProvider<List<Conversation>> conversationsProvider =
    FutureProvider<List<Conversation>>((Ref ref) async {
      final GatewayContext? context = await ref.watch(
        gatewayContextProvider.future,
      );
      if (context == null) {
        throw const ConversationRepositoryException(
          'Select a server and sign in to view conversations.',
        );
      }
      final ConversationsPage<Conversation> page = await ref
          .read(conversationRepositoryProvider)
          .loadConversations(
            server: context.server,
            accessToken: context.accessToken,
          );
      return page.items;
    });
