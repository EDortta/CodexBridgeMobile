/// Where a [Decision] sits in its own resolution lifecycle.
///
/// `pending` is the inbox's default filter (#25) — an operator opening
/// "Decisions" wants what still needs them, not the full history. Approving,
/// rejecting and requesting revision (#26) are what move a decision out of
/// `pending`.
enum DecisionState {
  pending,
  approved,
  rejected,
  needsRevision;

  String get label => switch (this) {
    DecisionState.pending => 'Pending',
    DecisionState.approved => 'Approved',
    DecisionState.rejected => 'Rejected',
    DecisionState.needsRevision => 'Needs revision',
  };
}
