import '../domain/conversation.dart';
import '../domain/conversation_repository.dart';

class MockConversationRepository implements ConversationRepository {
  @override
  Future<List<Conversation>> loadConversations() {
    return Future<List<Conversation>>.value(const <Conversation>[
      Conversation(
        id: 'foundation-thread',
        title: 'Foundation review',
        lastMessage: 'Shell and navigation are ready for review.',
      ),
      Conversation(
        id: 'release-thread',
        title: 'Release planning',
        lastMessage: 'Waiting on the operator decision.',
      ),
    ]);
  }
}
