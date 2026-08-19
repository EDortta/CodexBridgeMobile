/// A discussion entry on a [Decision] — the "discuss" action (#26), separate
/// from the formal resolution record (`DecisionAuditEvent`): a comment never
/// changes the decision's state.
class DecisionComment {
  const DecisionComment({
    required this.id,
    required this.author,
    required this.body,
    required this.postedAt,
  });

  final String id;
  final String author;
  final String body;
  final DateTime postedAt;
}
