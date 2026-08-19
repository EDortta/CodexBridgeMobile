/// How much is at stake if a [Decision] is resolved the wrong way.
enum DecisionRisk {
  high,
  medium,
  low;

  String get label => switch (this) {
    DecisionRisk.high => 'High risk',
    DecisionRisk.medium => 'Medium risk',
    DecisionRisk.low => 'Low risk',
  };
}
