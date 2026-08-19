import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/format/relative_moment.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/presentation/async_state_view.dart';
import '../../../core/presentation/filter_menu_button.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/decision.dart';
import '../domain/decision_risk.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';
import 'decision_filter.dart';
import 'decision_providers.dart';

/// Cross-cutting destination reached from every primary destination.
///
/// It is hosted above the shell on the root navigator, so it covers the
/// navigation bar instead of becoming a fifth destination.
///
/// #25's inbox: urgency, risk, state, project and deadline filters that
/// combine (`filterDecisions`), a critical decision visually distinct from
/// a routine one (never by color alone — an explicit "Critical" label
/// always accompanies the red border), and each card showing the request,
/// impact and agent recommendation summary #25 asks for. A card's full
/// context, evidence, discussion and the approve/reject/request-revision
/// actions themselves live on `DecisionDetailScreen` (#26), reached by
/// tapping a card.
class DecisionsScreen extends ConsumerWidget {
  const DecisionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decisions')),
      body: AsyncStateView<List<Decision>>(
        value: ref.watch(decisionsProvider),
        data: (BuildContext context, List<Decision> decisions) {
          return _DecisionInboxBody(decisions: decisions);
        },
      ),
    );
  }
}

class _DecisionInboxBody extends ConsumerWidget {
  const _DecisionInboxBody({required this.decisions});

  final List<Decision> decisions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DecisionUrgency? urgency = ref.watch(decisionUrgencyFilterProvider);
    final DecisionRisk? risk = ref.watch(decisionRiskFilterProvider);
    final DecisionState? state = ref.watch(decisionStateFilterProvider);
    final String? projectId = ref.watch(decisionProjectFilterProvider);
    final DecisionDeadlineFilter deadline = ref.watch(
      decisionDeadlineFilterProvider,
    );
    final DateTime now = ref.watch(appClockProvider)();

    final List<Decision> filtered = filterDecisions(
      decisions,
      urgency: urgency,
      risk: risk,
      state: state,
      projectId: projectId,
      deadline: deadline,
      now: now,
    );
    final List<String> projectIds =
        decisions.map((Decision d) => d.projectId).toSet().toList()..sort();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              FilterMenuButton<DecisionUrgency?>(
                key: const Key('decisionUrgencyFilter'),
                icon: Icons.priority_high_rounded,
                selected: urgency,
                options: const <DecisionUrgency?>[
                  null,
                  ...DecisionUrgency.values,
                ],
                labelOf: (DecisionUrgency? u) => u?.label ?? 'Any urgency',
                onSelected: (DecisionUrgency? value) =>
                    ref.read(decisionUrgencyFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<DecisionRisk?>(
                key: const Key('decisionRiskFilter'),
                icon: Icons.shield_outlined,
                selected: risk,
                options: const <DecisionRisk?>[null, ...DecisionRisk.values],
                labelOf: (DecisionRisk? r) => r?.label ?? 'Any risk',
                onSelected: (DecisionRisk? value) =>
                    ref.read(decisionRiskFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<DecisionState?>(
                key: const Key('decisionStateFilter'),
                icon: AppIcons.status,
                selected: state,
                options: const <DecisionState?>[null, ...DecisionState.values],
                labelOf: (DecisionState? s) => s?.label ?? 'Any state',
                onSelected: (DecisionState? value) =>
                    ref.read(decisionStateFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<String?>(
                key: const Key('decisionProjectFilter'),
                icon: AppIcons.projects,
                selected: projectId,
                options: <String?>[null, ...projectIds],
                labelOf: (String? p) => p ?? 'Any project',
                onSelected: (String? value) =>
                    ref.read(decisionProjectFilterProvider.notifier).state = value,
              ),
              FilterMenuButton<DecisionDeadlineFilter>(
                key: const Key('decisionDeadlineFilter'),
                icon: AppIcons.stale,
                selected: deadline,
                options: DecisionDeadlineFilter.values,
                labelOf: (DecisionDeadlineFilter d) => d.label,
                onSelected: (DecisionDeadlineFilter value) =>
                    ref.read(decisionDeadlineFilterProvider.notifier).state =
                        value,
              ),
            ],
          ),
        ),
        Expanded(
          child: decisions.isEmpty
              ? const _EmptyDecisionsView(
                  message: 'No decisions yet.',
                  showClearAction: false,
                )
              : filtered.isEmpty
              ? const _EmptyDecisionsView(
                  message: 'No decisions match your filters.',
                  showClearAction: true,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _DecisionCard(decision: filtered[index], now: now),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyDecisionsView extends ConsumerWidget {
  const _EmptyDecisionsView({
    required this.message,
    required this.showClearAction,
  });

  final String message;
  final bool showClearAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.decisions,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (showClearAction) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  ref.read(decisionUrgencyFilterProvider.notifier).state = null;
                  ref.read(decisionRiskFilterProvider.notifier).state = null;
                  ref.read(decisionStateFilterProvider.notifier).state = null;
                  ref.read(decisionProjectFilterProvider.notifier).state = null;
                  ref.read(decisionDeadlineFilterProvider.notifier).state =
                      DecisionDeadlineFilter.all;
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision, required this.now});

  final Decision decision;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isCritical = decision.urgency == DecisionUrgency.critical;
    final bool isResolved = decision.state != DecisionState.pending;
    final Color accent = isCritical
        ? theme.colorScheme.error
        : theme.colorScheme.outlineVariant;

    return Opacity(
      // Resolved decisions are kept visible (state-filter history, #25) but
      // deliberately recede — never the *only* signal that they are settled:
      // the state badge below always says so in words too.
      opacity: isResolved ? 0.6 : 1.0,
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: accent, width: isCritical ? 2 : 1),
            borderRadius: AppRadius.card,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () => context.go(
            Uri(
              path: AppRoutes.decisionDetail,
              queryParameters: <String, String>{'decision': decision.id},
            ).toString(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isCritical)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.priority_high_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Critical',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(decision.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xxs,
                  children: <Widget>[
                    InlineBadge(icon: AppIcons.status, text: decision.state.label),
                    InlineBadge(
                      icon: Icons.shield_outlined,
                      text: decision.risk.label,
                    ),
                    InlineBadge(
                      icon: AppIcons.stale,
                      text: describeDeadline(decision.deadline, now),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(decision.impactSummary, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Recommendation: ${decision.recommendationSummary}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
