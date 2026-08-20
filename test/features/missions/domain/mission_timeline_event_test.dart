import 'package:codex_bridge_mobile/features/missions/domain/mission_timeline_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every field round-trips through the constructor', () {
    final DateTime occurredAt = DateTime.utc(2026, 8, 19, 12);

    final MissionTimelineEvent event = MissionTimelineEvent(
      id: 'm-1-timeline-1',
      description: 'Mission started',
      actor: 'Claude',
      occurredAt: occurredAt,
    );

    expect(event.id, 'm-1-timeline-1');
    expect(event.description, 'Mission started');
    expect(event.actor, 'Claude');
    expect(event.occurredAt, occurredAt);
  });
}
