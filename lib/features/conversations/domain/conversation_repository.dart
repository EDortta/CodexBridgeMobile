import 'conversation.dart';

abstract interface class ConversationRepository {
  Future<List<Conversation>> loadConversations();
}
