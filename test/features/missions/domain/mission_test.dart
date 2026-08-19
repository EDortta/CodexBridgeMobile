import 'package:codex_bridge_mobile/features/missions/domain/mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projectId round-trips through the constructor', () {
    const Mission mission = Mission(
      id: 'm-1',
      projectId: 'codex-bridge-mobile',
      title: 'Title',
      status: 'Status',
    );

    expect(mission.projectId, 'codex-bridge-mobile');
  });
}
