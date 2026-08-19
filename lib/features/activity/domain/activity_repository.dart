import 'activity_entry.dart';

abstract interface class ActivityRepository {
  Future<List<ActivityEntry>> loadActivity();
}
