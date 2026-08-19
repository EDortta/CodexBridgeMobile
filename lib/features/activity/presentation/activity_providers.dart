import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_activity_repository.dart';
import '../domain/activity_entry.dart';
import '../domain/activity_repository.dart';

final Provider<ActivityRepository> activityRepositoryProvider =
    Provider<ActivityRepository>((Ref ref) => MockActivityRepository());

final FutureProvider<List<ActivityEntry>> activityProvider =
    FutureProvider<List<ActivityEntry>>((Ref ref) async {
      return ref.watch(activityRepositoryProvider).loadActivity();
    });
