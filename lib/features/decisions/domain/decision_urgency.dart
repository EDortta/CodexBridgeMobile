/// How soon a [Decision] needs a human response.
enum DecisionUrgency {
  critical,
  high,
  normal,
  low;

  String get label => switch (this) {
    DecisionUrgency.critical => 'Critical',
    DecisionUrgency.high => 'High',
    DecisionUrgency.normal => 'Normal',
    DecisionUrgency.low => 'Low',
  };
}
