import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_mission_repository.dart';
import '../domain/mission.dart';
import '../domain/mission_repository.dart';

final Provider<MissionRepository> missionRepositoryProvider =
    Provider<MissionRepository>((Ref ref) => MockMissionRepository());

final FutureProvider<List<Mission>> missionsProvider =
    FutureProvider<List<Mission>>((Ref ref) async {
      return ref.watch(missionRepositoryProvider).loadMissions();
    });
