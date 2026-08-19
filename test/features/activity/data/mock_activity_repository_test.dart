import 'package:codex_bridge_mobile/features/activity/data/mock_activity_repository.dart';
import 'package:codex_bridge_mobile/features/activity/domain/activity_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every mock project id is represented, with no duplicate ids', () async {
    final List<ActivityEntry> entries = await MockActivityRepository().loadActivity();

    expect(
      entries.map((ActivityEntry e) => e.projectId).toSet(),
      <String>{
        'codex-bridge-mobile',
        'codex-bridge',
        'codex-bridge-desktop',
        'codex-bridge-cli',
      },
    );
    expect(
      entries.map((ActivityEntry e) => e.id).toSet(),
      hasLength(entries.length),
    );
  });
}
