import '../../../core/format/utc_moment.dart';

/// The inbox's deadline filter (#25) — a UI-only bucketing of
/// `Decision.deadline`, not a domain concept, so it lives in
/// `presentation/` rather than `domain/`.
enum DecisionDeadlineFilter {
  all,
  overdue,
  dueToday,
  dueThisWeek;

  String get label => switch (this) {
    DecisionDeadlineFilter.all => 'Any deadline',
    DecisionDeadlineFilter.overdue => 'Overdue',
    DecisionDeadlineFilter.dueToday => 'Due today',
    DecisionDeadlineFilter.dueThisWeek => 'Due this week',
  };
}

/// Which bucket [deadline] falls into as of [now]. `dueToday` covers the
/// next 24 hours rather than the calendar day, so it agrees with whatever
/// time zone `now` is expressed in without a separate calendar computation.
DecisionDeadlineFilter classifyDeadline(DateTime deadline, DateTime now) {
  final Duration until = deadline.difference(now);
  if (until.isNegative) {
    return DecisionDeadlineFilter.overdue;
  }
  if (until <= const Duration(hours: 24)) {
    return DecisionDeadlineFilter.dueToday;
  }
  if (until <= const Duration(days: 7)) {
    return DecisionDeadlineFilter.dueThisWeek;
  }
  return DecisionDeadlineFilter.all;
}

/// A short label for [deadline]'s bucket — shared by the inbox card (#25)
/// and the detail screen (#26) so both describe a deadline the same way.
String describeDeadline(DateTime deadline, DateTime now) {
  return switch (classifyDeadline(deadline, now)) {
    DecisionDeadlineFilter.overdue => 'Overdue (${UtcMoment.day(deadline)})',
    DecisionDeadlineFilter.dueToday => 'Due today',
    DecisionDeadlineFilter.dueThisWeek => 'Due this week',
    DecisionDeadlineFilter.all => 'Due ${UtcMoment.day(deadline)}',
  };
}
