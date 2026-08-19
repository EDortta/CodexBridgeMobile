import 'package:codex_bridge_mobile/features/decisions/presentation/decision_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 12);

  group('classifyDeadline', () {
    test('a deadline already passed is overdue', () {
      expect(
        classifyDeadline(now.subtract(const Duration(hours: 1)), now),
        DecisionDeadlineFilter.overdue,
      );
    });

    test('a deadline exactly now has not yet passed: dueToday, not overdue', () {
      expect(classifyDeadline(now, now), DecisionDeadlineFilter.dueToday);
    });

    test('a deadline within the next 24 hours is dueToday', () {
      expect(
        classifyDeadline(now.add(const Duration(hours: 23)), now),
        DecisionDeadlineFilter.dueToday,
      );
    });

    test('a deadline within the next 7 days, past 24h, is dueThisWeek', () {
      expect(
        classifyDeadline(now.add(const Duration(days: 3)), now),
        DecisionDeadlineFilter.dueThisWeek,
      );
    });

    test('a deadline more than 7 days out is neither bucket', () {
      expect(
        classifyDeadline(now.add(const Duration(days: 8)), now),
        DecisionDeadlineFilter.all,
      );
    });
  });
}
