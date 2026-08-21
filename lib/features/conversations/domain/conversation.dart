/// The closed vocabulary a [ContextReference] may name — mirrors
/// `ConversationContextType` in `docs/api/codex-bridge.openapi.yaml` and
/// `gateway/app/services/conversation_types.py:CONTEXT_TYPES` on the
/// `CodexBridge` server.
///
/// `artifact` is deliberately absent, not merely unimplemented: the server
/// has no `ArtifactModel` to check such a reference against (issue #11 has
/// not shipped it), so it is omitted from the vocabulary on both sides
/// rather than accepted here and rejected there. A client that sent it would
/// always get `400 invalid_context_type` back — there is no version of this
/// enum that includes it today.
enum ConversationContextType {
  project,
  session,
  decision,
  mission,
  issue;

  static ConversationContextType? parse(String raw) {
    return switch (raw) {
      'project' => ConversationContextType.project,
      'session' => ConversationContextType.session,
      'decision' => ConversationContextType.decision,
      'mission' => ConversationContextType.mission,
      'issue' => ConversationContextType.issue,
      _ => null,
    };
  }

  /// The wire spelling, identical to [name] for every member of this enum —
  /// spelled out explicitly so a future member cannot silently change the
  /// wire value by renaming.
  String get wire => switch (this) {
    ConversationContextType.project => 'project',
    ConversationContextType.session => 'session',
    ConversationContextType.decision => 'decision',
    ConversationContextType.mission => 'mission',
    ConversationContextType.issue => 'issue',
  };
}

/// One product entity a conversation is about — a project, a
/// session/decision/mission (the same `TaskModel` under three vocabularies
/// on the server), or an issue. Every [Conversation] carries at least one.
class ContextReference {
  const ContextReference({required this.type, required this.id});

  final ConversationContextType type;
  final String id;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wire,
    'id': id,
  };

  static ContextReference? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final String? typeRaw = json['type'] is String ? json['type']! as String : null;
    final String? id = _nonEmpty(json['id']);
    final ConversationContextType? type = typeRaw == null
        ? null
        : ConversationContextType.parse(typeRaw);
    if (type == null || id == null) {
      return null;
    }
    return ContextReference(type: type, id: id);
  }
}

/// A thread linked to at least one product entity
/// (`gateway/app/api/routes/conversations.py`, `CodexBridge` issue #10).
///
/// `projectId` is derived server-side from [context] — every reference in it
/// resolves to the same project — never supplied independently, which is
/// also why [ConversationRepository.createConversation] takes no
/// `projectId` parameter of its own.
class Conversation {
  const Conversation({
    required this.id,
    required this.projectId,
    required this.context,
    required this.unread,
    required this.createdAt,
    this.title,
    this.lastActivityAt,
    this.createdBy,
  });

  final String id;
  final String projectId;
  final String? title;
  final List<ContextReference> context;

  /// Whether the caller has unseen activity. There is no "mark as read"
  /// endpoint — this only ever advances through `GET .../messages` (up to
  /// the newest message actually fetched, never to "now") and
  /// `POST .../messages` (the sender's own cursor). See the server route
  /// module's docstring for the full reasoning; a client must not infer a
  /// different meaning for this field than that.
  final bool unread;

  /// Timestamp of the most recent message, or `null` when there are none
  /// yet. Never used to order the conversations list — see
  /// [ConversationRepository.loadConversations].
  final DateTime? lastActivityAt;

  final DateTime createdAt;
  final String? createdBy;

  static Conversation fromJson(Map<String, Object?> json) {
    final String? id = _nonEmpty(json['id']);
    final String? projectId = _nonEmpty(json['projectId']);
    final DateTime? createdAt = _instant(json['createdAt']);
    final Object? unreadRaw = json['unread'];
    final bool? unread = unreadRaw is bool ? unreadRaw : null;
    final List<ContextReference>? context = _contextList(json['context']);
    if (id == null ||
        projectId == null ||
        createdAt == null ||
        unread == null ||
        context == null ||
        context.isEmpty) {
      throw const FormatException('invalid_conversation_payload');
    }
    return Conversation(
      id: id,
      projectId: projectId,
      title: _nonEmpty(json['title']),
      context: context,
      unread: unread,
      lastActivityAt: _instant(json['lastActivityAt']),
      createdAt: createdAt,
      createdBy: _nonEmpty(json['createdBy']),
    );
  }

  static List<ContextReference>? _contextList(Object? value) {
    if (value is! List<Object?>) {
      return null;
    }
    final List<ContextReference> parsed = <ContextReference>[];
    for (final Object? item in value) {
      final ContextReference? reference = ContextReference.fromJson(item);
      if (reference == null) {
        return null;
      }
      parsed.add(reference);
    }
    return parsed;
  }
}

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _instant(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
