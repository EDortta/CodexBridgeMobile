import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_conversation_repository.dart';
import '../domain/conversation.dart';
import '../domain/conversation_repository.dart';

final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((Ref ref) => MockConversationRepository());

final FutureProvider<List<Conversation>> conversationsProvider =
    FutureProvider<List<Conversation>>((Ref ref) async {
      return ref.watch(conversationRepositoryProvider).loadConversations();
    });
