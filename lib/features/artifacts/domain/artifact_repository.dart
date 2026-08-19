import 'artifact.dart';

abstract interface class ArtifactRepository {
  Future<List<Artifact>> loadArtifacts();
}
