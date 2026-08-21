/// One message inside a [Conversation]'s thread
/// (`gateway/app/api/routes/conversations.py`, `CodexBridge` issue #10).
///
/// Append-only: there is no revision, no `ETag`, no `If-Match` and no update
/// endpoint anywhere in this feature, unlike `LiveSession`/`controlSession`.
/// A message, once posted, is not edited or deleted through this contract.
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.attachments,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String conversationId;

  /// Email, or id when no email is on record, of who sent this. `null` is a
  /// valid value the server itself sends, not a parse failure.
  final String? author;

  /// Markdown source, stored and returned unrendered. Rendering it is this
  /// app's responsibility, not the server's.
  final String body;

  /// Opaque artifact/file identifiers, recorded and returned exactly as
  /// sent — unvalidated, because no `ArtifactModel` exists yet (issue #11).
  final List<String> attachments;

  final DateTime createdAt;

  static ConversationMessage fromJson(Map<String, Object?> json) {
    final String? id = _nonEmpty(json['id']);
    final String? conversationId = _nonEmpty(json['conversationId']);
    final String? body = json['body'] is String ? json['body']! as String : null;
    final DateTime? createdAt = _instant(json['createdAt']);
    final List<String>? attachments = _stringList(json['attachments']);
    if (id == null ||
        conversationId == null ||
        body == null ||
        createdAt == null ||
        attachments == null) {
      throw const FormatException('invalid_message_payload');
    }
    return ConversationMessage(
      id: id,
      conversationId: conversationId,
      author: _nonEmpty(json['author']),
      body: body,
      attachments: attachments,
      createdAt: createdAt,
    );
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List<Object?>) {
      return null;
    }
    final List<String> result = <String>[];
    for (final Object? item in value) {
      if (item is! String) {
        return null;
      }
      result.add(item);
    }
    return result;
  }
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _instant(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
