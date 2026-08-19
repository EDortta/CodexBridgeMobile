import 'package:codex_bridge_mobile/features/decisions/domain/decision_comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fields round-trip through the constructor', () {
    final DateTime postedAt = DateTime.utc(2026, 8, 19, 12);
    final DecisionComment comment = DecisionComment(
      id: 'c-1',
      author: 'You',
      body: 'Looks good to me.',
      postedAt: postedAt,
    );

    expect(comment.id, 'c-1');
    expect(comment.author, 'You');
    expect(comment.body, 'Looks good to me.');
    expect(comment.postedAt, postedAt);
  });
}
