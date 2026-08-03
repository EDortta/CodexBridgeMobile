import '../domain/mission.dart';
import '../domain/mission_repository.dart';

class MockMissionRepository implements MissionRepository {
  @override
  Future<List<Mission>> loadMissions() {
    return Future<List<Mission>>.value(const <Mission>[
      Mission(
        id: 'mobile-foundation',
        title: 'Codex Bridge Mobile',
        status: 'Local foundation active',
      ),
    ]);
  }
}
