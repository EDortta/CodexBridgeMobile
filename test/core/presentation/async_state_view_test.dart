import 'package:codex_bridge_mobile/core/presentation/async_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders loading data and error states consistently', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_view(AsyncValue<String>.loading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      _view(const AsyncValue<String>.data('Mission data')),
    );
    expect(find.text('Mission data'), findsOneWidget);

    await tester.pumpWidget(
      _view(
        AsyncValue<String>.error(
          StateError('repository unavailable'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text('Unable to load this view.'), findsOneWidget);
  });
}

Widget _view(AsyncValue<String> value) {
  return MaterialApp(
    home: AsyncStateView<String>(
      value: value,
      data: (BuildContext context, String result) => Text(result),
    ),
  );
}
