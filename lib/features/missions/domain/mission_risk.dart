/// How much is at stake if a [Mission] goes wrong.
///
/// Deliberately a separate type from `DecisionRisk`
/// (`features/decisions/domain/`) even though the values are the same
/// shape — a feature must never import another feature
/// (`docs/architecture/state-architecture.md`), so each risk concept that
/// needs one owns its own enum.
enum MissionRisk {
  high,
  medium,
  low;

  String get label => switch (this) {
    MissionRisk.high => 'High risk',
    MissionRisk.medium => 'Medium risk',
    MissionRisk.low => 'Low risk',
  };
}
