import '../domain/activity_entry.dart';
import '../domain/activity_repository.dart';

/// Stands in for a real activity endpoint until one exists. The closest
/// CodexBridge issue is #13 ("Expose mobile event stream and notification
/// subscription API"), open — but it is a live push/subscription contract,
/// not a historical activity log, so it is named here honestly as the
/// nearest fit rather than a confirmed match. `occurredAt` is spread across
/// recent and old values so the dashboard's 7-day staleness marking has
/// something real to demonstrate.
class MockActivityRepository implements ActivityRepository {
  @override
  Future<List<ActivityEntry>> loadActivity() {
    return Future<List<ActivityEntry>>.value(<ActivityEntry>[
      ActivityEntry(
        id: 'mobile-merged-gh-23',
        projectId: 'codex-bridge-mobile',
        description: 'Merged #23: projects list, search and filters',
        occurredAt: DateTime.utc(2026, 8, 19, 8),
      ),
      ActivityEntry(
        id: 'bridge-build-failed',
        projectId: 'codex-bridge',
        description: 'Development build failed',
        occurredAt: DateTime.utc(2026, 8, 18, 22),
      ),
      ActivityEntry(
        id: 'desktop-review-requested',
        projectId: 'codex-bridge-desktop',
        description: 'Design review requested',
        occurredAt: DateTime.utc(2026, 8, 19, 10),
      ),
      ActivityEntry(
        id: 'cli-last-heartbeat',
        projectId: 'codex-bridge-cli',
        description: 'Last heartbeat received',
        occurredAt: DateTime.utc(2026, 8, 5),
      ),
    ]);
  }
}
