import 'package:codex_bridge_mobile/features/decisions/domain/decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projectId and requestedAt round-trip through the constructor', () {
    final DateTime requestedAt = DateTime.utc(2026, 8, 15, 9);
    final Decision decision = Decision(
      id: 'd-1',
      projectId: 'codex-bridge-desktop',
      title: 'Title',
      requestedBy: 'Someone',
      requestedAt: requestedAt,
    );

    expect(decision.projectId, 'codex-bridge-desktop');
    expect(decision.requestedAt, requestedAt);
  });
}
