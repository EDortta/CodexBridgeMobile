import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/decision.dart';
import 'decision_providers.dart';

/// Cross-cutting destination reached from every primary destination.
///
/// It is hosted above the shell on the root navigator, so it covers the
/// navigation bar instead of becoming a fifth destination.
class DecisionsScreen extends ConsumerWidget {
  const DecisionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decisions')),
      body: AsyncStateView<List<Decision>>(
        value: ref.watch(pendingDecisionsProvider),
        data: (BuildContext context, List<Decision> decisions) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: decisions.length,
            itemBuilder: (BuildContext context, int index) {
              final Decision decision = decisions[index];
              return ListTile(
                leading: const Icon(AppIcons.decisions),
                title: Text(decision.title),
                subtitle: Text(decision.requestedBy),
              );
            },
          );
        },
      ),
    );
  }
}
