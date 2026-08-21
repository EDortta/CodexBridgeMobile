/// One page of a cursor-paginated collection — mirrors `PageInfo` in
/// `docs/api/codex-bridge.openapi.yaml`: `hasMore` is authoritative (a short
/// page does not itself mean the end of the list — items can be filtered out
/// by authorization), and [nextCursor] is opaque and single-purpose, valid
/// only against the same endpoint under the same filters that produced it.
///
/// Generic across [Conversation] and [ConversationMessage] rather than two
/// near-identical classes: both pages carry exactly this shape and nothing
/// feature-specific.
class ConversationsPage<T> {
  const ConversationsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
}
