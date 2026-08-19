/// Where a [Mission] sits in its own work lifecycle — planning through
/// documentation, per Epic #5's scope ("Modelar planejamento, implementação,
/// testes, validação e documentação").
enum MissionStage {
  planning,
  implementation,
  testing,
  validation,
  documentation;

  String get label => switch (this) {
    MissionStage.planning => 'Planning',
    MissionStage.implementation => 'Implementation',
    MissionStage.testing => 'Testing',
    MissionStage.validation => 'Validation',
    MissionStage.documentation => 'Documentation',
  };
}
