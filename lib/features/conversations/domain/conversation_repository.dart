import 'conversation.dart';
import 'conversation_message.dart';
import 'conversation_page.dart';

/// The five conversation endpoints
/// (`gateway/app/api/routes/conversations.py`, `CodexBridge` issue #10),
/// as a repository interface. `server`/`accessToken` are passed per call
/// rather than injected, the same convention [LiveSessionRepository] uses —
/// a feature-local repository has no session of its own to remember.
abstract interface class ConversationRepository {
  /// Conversations the caller may see, newest-created first. Ordered by
  /// `createdAt`/`id` — **never** `lastActivityAt`: sorting by an activity
  /// timestamp would move a conversation's position the instant a new
  /// message lands, which can skip or repeat rows across a paginated walk.
  /// A caller that wants "most recently active first" sorts [ConversationsPage.items]
  /// itself using [Conversation.lastActivityAt].
  Future<ConversationsPage<Conversation>> loadConversations({
    required Uri server,
    required String accessToken,
    List<String>? projectIds,
    String? cursor,
    int? limit,
  });

  Future<Conversation> loadConversation({
    required Uri server,
    required String accessToken,
    required String conversationId,
  });

  /// A conversation's messages, **oldest first** — the opposite order of
  /// every other collection in this app, because a thread is read forward
  /// from where it starts.
  ///
  /// Fetching a page advances the caller's own unread cursor to the newest
  /// message actually returned in it, as a side effect on the server —
  /// there is no separate "mark as read" call to make instead.
  Future<ConversationsPage<ConversationMessage>> loadMessages({
    required Uri server,
    required String accessToken,
    required String conversationId,
    String? cursor,
    int? limit,
  });

  /// Posts a message. [idempotencyKey], when supplied, is sent as
  /// `Idempotency-Key` so a caller that retries the same logical send after
  /// losing the network gets the original message back instead of a
  /// duplicate — the caller must reuse the same key across retries of one
  /// logical send for that property to hold; a fresh key per attempt is a
  /// fresh message. When omitted, [HttpConversationRepository] generates one
  /// itself so the request is still idempotent against transport-level
  /// retries within that single call, though not across separate calls.
  Future<ConversationMessage> postMessage({
    required Uri server,
    required String accessToken,
    required String conversationId,
    required String body,
    List<String>? attachments,
    String? idempotencyKey,
  });

  /// Starts a conversation. `projectId` is not a parameter here: the
  /// server derives it from [context], and rejects (`mixed_project`) a
  /// [context] whose references do not all resolve to the same project.
  /// See [postMessage] for [idempotencyKey]'s reuse-across-retries contract.
  Future<Conversation> createConversation({
    required Uri server,
    required String accessToken,
    required List<ContextReference> context,
    String? title,
    String? idempotencyKey,
  });
}

/// Thrown by every [ConversationRepository] implementation on a failure a
/// caller must handle — never lets a transport exception (`SocketException`,
/// a `FormatException` from a malformed body, …) escape past this feature's
/// boundary, the same discipline `LiveSessionRepositoryException` applies.
class ConversationRepositoryException implements Exception {
  const ConversationRepositoryException(
    this.message, {
    this.code,
    this.notFound = false,
  });

  final String message;

  /// The server's `Error.code` (or the more specific `details[0].code` when
  /// the response carries one, e.g. `mixed_project`), when the failure came
  /// from a response the server actually sent. `null` for a transport
  /// failure, a timeout, or a malformed body this app could not parse.
  final String? code;

  /// Whether this failure is specifically "no such resource" (`404`) as
  /// opposed to "forbidden" (`403`) or anything else. The server answers
  /// both a genuinely missing conversation and one outside the caller's
  /// visible projects with the same `404` — never a `403` that would
  /// disclose one exists — and a caller here must keep telling those apart
  /// from a `403` on an endpoint that does use it, rather than collapsing
  /// every non-2xx into one generic "failed" state.
  final bool notFound;
}
