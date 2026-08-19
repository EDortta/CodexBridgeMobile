import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_mission_repository.dart';
import '../domain/mission.dart';
import '../domain/mission_repository.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_stage.dart';
import '../domain/mission_state.dart';

final Provider<MissionRepository> missionRepositoryProvider =
    Provider<MissionRepository>((Ref ref) => MockMissionRepository());

final FutureProvider<List<Mission>> missionsProvider =
    FutureProvider<List<Mission>>((Ref ref) async {
      return ref.watch(missionRepositoryProvider).loadMissions();
    });

final StateProvider<String?> missionProjectFilterProvider =
    StateProvider<String?>((Ref ref) => null);

final StateProvider<MissionStage?> missionStageFilterProvider =
    StateProvider<MissionStage?>((Ref ref) => null);

final StateProvider<MissionRisk?> missionRiskFilterProvider =
    StateProvider<MissionRisk?>((Ref ref) => null);

final StateProvider<MissionState?> missionStateFilterProvider =
    StateProvider<MissionState?>((Ref ref) => null);

/// Pure so it is testable without pumping a widget, the same reasoning
/// `filterProjectListItems`/`filterDecisions` document. Every axis is
/// independently optional and combines with AND — #27's "list/filter UI by
/// project, stage, risk and state".
List<Mission> filterMissions(
  List<Mission> missions, {
  required String? projectId,
  required MissionStage? stage,
  required MissionRisk? risk,
  required MissionState? state,
}) {
  return missions.where((Mission mission) {
    if (projectId != null && mission.projectId != projectId) {
      return false;
    }
    if (stage != null && mission.stage != stage) {
      return false;
    }
    if (risk != null && mission.risk != risk) {
      return false;
    }
    if (state != null && mission.state != state) {
      return false;
    }
    return true;
  }).toList(growable: false);
}
