import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({required this.value, required this.data, super.key});

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) =>
          const Center(child: Text('Unable to load this view.')),
      data: (T result) => data(context, result),
    );
  }
}
