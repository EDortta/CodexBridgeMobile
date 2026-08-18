import 'package:codex_bridge_mobile/features/missions/domain/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a remote session and exposes the control affordances', () {
    final LiveSession session = LiveSession.fromJson(<String, Object?>{
      'id': 's-1',
      'projectId': 'codexbridge',
      'executorId': 'devel3',
      'instruction': 'Investigate the failing task',
      'state': 'running',
      'priority': 'normal',
      'revision': 7,
      'createdAt': '2026-08-15T12:00:00Z',
      'startedAt': '2026-08-15T12:01:00Z',
    });

    expect(session.id, 's-1');
    expect(session.state, LiveSessionState.running);
    expect(session.canPause, isTrue);
    expect(session.canResume, isFalse);
    expect(session.canRestart, isTrue);
    expect(session.canStop, isTrue);
  });

  test('refuses an incomplete payload instead of inventing a session', () {
    expect(
      () => LiveSession.fromJson(<String, Object?>{
        'id': 's-1',
        'state': 'running',
      }),
      throwsFormatException,
    );
  });

  test(
    'canRestart mirrors the gateway\'s FINISHED_RESTARTABLE set, not only the live one',
    () {
      LiveSession sessionIn(String state) => LiveSession.fromJson(<String, Object?>{
        'id': 's-1',
        'projectId': 'codexbridge',
        'executorId': 'devel3',
        'instruction': 'Investigate the failing task',
        'state': state,
        'priority': 'normal',
        'revision': 7,
        'createdAt': '2026-08-15T12:00:00Z',
      });

      // council 2026-08-18, round 2: the only prior assertion here used
      // 'running', which was already restartable before this fix and so
      // could not distinguish the fixed behaviour from the pre-fix one.
      for (final String restartable in <String>[
        'running',
        'paused',
        'completed',
        'failed',
        'cancelled',
        'expired',
        'lost',
      ]) {
        expect(
          sessionIn(restartable).canRestart,
          isTrue,
          reason: '$restartable should be restartable',
        );
      }
      for (final String notRestartable in <String>[
        'queued',
        'waiting_executor',
        'awaiting_approval',
        'pausing',
        'resuming',
        'restarting',
      ]) {
        expect(
          sessionIn(notRestartable).canRestart,
          isFalse,
          reason: '$notRestartable should not be restartable',
        );
      }
    },
  );
}
