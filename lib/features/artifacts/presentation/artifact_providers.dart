import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_artifact_repository.dart';
import '../domain/artifact.dart';
import '../domain/artifact_repository.dart';

final Provider<ArtifactRepository> artifactRepositoryProvider =
    Provider<ArtifactRepository>((Ref ref) => MockArtifactRepository());

final FutureProvider<List<Artifact>> artifactsProvider =
    FutureProvider<List<Artifact>>((Ref ref) async {
      return ref.watch(artifactRepositoryProvider).loadArtifacts();
    });
