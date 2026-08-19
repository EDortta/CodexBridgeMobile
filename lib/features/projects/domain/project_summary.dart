import 'project_health.dart';

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.health,
    this.attentionSummary,
  });

  final String id;
  final String name;
  final ProjectHealth health;

  /// A short, card-visible reason this project needs attention — for example
  /// "2 decisions waiting" or "Build failing on development".
  ///
  /// Null when [health] already says everything the card needs to show
  /// without opening the project (`active`, or an `offline`/`unhealthy`
  /// project with nothing more specific to report yet).
  final String? attentionSummary;
}
