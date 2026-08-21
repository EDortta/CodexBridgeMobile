import '../domain/conversation.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_page.dart';
import '../domain/conversation_repository.dart';

/// An in-memory stand-in for [ConversationRepository], used for widget tests
/// and UI work that never installs [HttpConversationRepository] — the
/// `conversationRepositoryProvider` default in every build except release,
/// the same role [MockAuthGateway] plays for auth (`conversation_repository_binding.dart`).
///
/// No pagination, no idempotency replay: every mutation just appends. That is
/// a deliberate scope cut — [HttpConversationRepository] is the
/// contract-accurate implementation, exercised against a real server in its
/// own tests; this class only has to keep the conversations list and detail
/// screens on-screen presentable while signed out of a real gateway.
class MockConversationRepository implements ConversationRepository {
  MockConversationRepository()
    : _conversations = <Conversation>[
        Conversation(
          id: 'foundation-thread',
          projectId: 'codex-bridge-mobile',
          title: 'Foundation review',
          context: const <ContextReference>[
            ContextReference(
              type: ConversationContextType.project,
              id: 'codex-bridge-mobile',
            ),
          ],
          unread: false,
          lastActivityAt: DateTime.utc(2026, 8, 20, 9),
          createdAt: DateTime.utc(2026, 8, 18, 10),
          createdBy: 'esteban',
        ),
        Conversation(
          id: 'release-thread',
          projectId: 'codex-bridge-mobile',
          title: 'Release planning',
          context: const <ContextReference>[
            ContextReference(
              type: ConversationContextType.project,
              id: 'codex-bridge-mobile',
            ),
          ],
          unread: true,
          lastActivityAt: DateTime.utc(2026, 8, 21, 8),
          createdAt: DateTime.utc(2026, 8, 19, 14),
          createdBy: 'esteban',
        ),
      ],
      _messages = <String, List<ConversationMessage>>{
        'foundation-thread': <ConversationMessage>[
          ConversationMessage(
            id: 'foundation-thread-m1',
            conversationId: 'foundation-thread',
            author: 'esteban',
            body: 'Shell and navigation are ready for review.',
            attachments: const <String>[],
            createdAt: DateTime.utc(2026, 8, 20, 9),
          ),
        ],
        'release-thread': <ConversationMessage>[
          ConversationMessage(
            id: 'release-thread-m1',
            conversationId: 'release-thread',
            author: 'esteban',
            body: 'Waiting on the operator decision.',
            attachments: const <String>[],
            createdAt: DateTime.utc(2026, 8, 21, 8),
          ),
        ],
      };

  final List<Conversation> _conversations;
  final Map<String, List<ConversationMessage>> _messages;
  int _sequence = 0;

  @override
  Future<ConversationsPage<Conversation>> loadConversations({
    required Uri server,
    required String accessToken,
    List<String>? projectIds,
    String? cursor,
    int? limit,
  }) async {
    final Iterable<Conversation> matching = projectIds == null || projectIds.isEmpty
        ? _conversations
        : _conversations.where((Conversation c) => projectIds.contains(c.projectId));
    return ConversationsPage<Conversation>(
      items: matching.toList(growable: false),
      hasMore: false,
    );
  }

  @override
  Future<Conversation> loadConversation({
    required Uri server,
    required String accessToken,
    required String conversationId,
  }) async {
    final Conversation? found = _find(conversationId);
    if (found == null) {
      throw const ConversationRepositoryException(
        'No such conversation.',
        code: 'not_found',
        notFound: true,
      );
    }
    return found;
  }

  @override
  Future<ConversationsPage<ConversationMessage>> loadMessages({
    required Uri server,
    required String accessToken,
    required String conversationId,
    String? cursor,
    int? limit,
  }) async {
    if (_find(conversationId) == null) {
      throw const ConversationRepositoryException(
        'No such conversation.',
        code: 'not_found',
        notFound: true,
      );
    }
    return ConversationsPage<ConversationMessage>(
      items: List<ConversationMessage>.of(_messages[conversationId] ?? const <ConversationMessage>[]),
      hasMore: false,
    );
  }

  @override
  Future<ConversationMessage> postMessage({
    required Uri server,
    required String accessToken,
    required String conversationId,
    required String body,
    List<String>? attachments,
    String? idempotencyKey,
  }) async {
    final Conversation? conversation = _find(conversationId);
    if (conversation == null) {
      throw const ConversationRepositoryException(
        'No such conversation.',
        code: 'not_found',
        notFound: true,
      );
    }
    final ConversationMessage message = ConversationMessage(
      id: '$conversationId-m${++_sequence}',
      conversationId: conversationId,
      author: 'esteban',
      body: body,
      attachments: List<String>.unmodifiable(attachments ?? const <String>[]),
      createdAt: DateTime.timestamp(),
    );
    _messages.putIfAbsent(conversationId, () => <ConversationMessage>[]).add(message);
    _replace(
      conversation.id,
      Conversation(
        id: conversation.id,
        projectId: conversation.projectId,
        title: conversation.title,
        context: conversation.context,
        unread: conversation.unread,
        lastActivityAt: message.createdAt,
        createdAt: conversation.createdAt,
        createdBy: conversation.createdBy,
      ),
    );
    return message;
  }

  @override
  Future<Conversation> createConversation({
    required Uri server,
    required String accessToken,
    required List<ContextReference> context,
    String? title,
    String? idempotencyKey,
  }) async {
    if (context.isEmpty) {
      throw const ConversationRepositoryException(
        'Every conversation must reference at least one project, session, '
        'decision, mission or issue.',
        code: 'validation_failed',
      );
    }
    final Conversation conversation = Conversation(
      id: 'mock-conversation-${++_sequence}',
      projectId: context.first.id,
      title: title,
      context: List<ContextReference>.unmodifiable(context),
      unread: false,
      createdAt: DateTime.timestamp(),
      createdBy: 'esteban',
    );
    _conversations.insert(0, conversation);
    _messages[conversation.id] = <ConversationMessage>[];
    return conversation;
  }

  Conversation? _find(String id) {
    for (final Conversation conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  void _replace(String id, Conversation updated) {
    final int index = _conversations.indexWhere((Conversation c) => c.id == id);
    if (index != -1) {
      _conversations[index] = updated;
    }
  }
}
