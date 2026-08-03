import 'mission.dart';

abstract interface class MissionRepository {
  Future<List<Mission>> loadMissions();
}
