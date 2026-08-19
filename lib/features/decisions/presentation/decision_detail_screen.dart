import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/relative_moment.dart';
import '../../../core/format/utc_moment.dart';
import '../domain/decision.dart';
import '../domain/decision_audit_event.dart';
import '../domain/decision_comment.dart';
import '../domain/decision_repository.dart';
import '../domain/decision_state.dart';
import '../domain/decision_urgency.dart';
import 'decision_badge.dart';
import 'decision_filter.dart';
import 'decision_providers.dart';

/// #26: full context, evidence, discussion and resolution history for one
/// decision, plus the approve/reject/request-revision/discuss actions.
///
/// Rejection and request-revision both require a non-empty comment
/// (`_ResolutionDialog`); a critical decision additionally requires an
/// explicit, decision-specific acknowledgement checkbox before any
/// state-changing action submits — deliberately *not* the plain Yes/No
/// confirmation `runSessionControlAction` (`features/missions/`) uses for
/// session stop/restart, since the epic for this screen rules out "generic"
/// confirmation for critical actions.
class DecisionDetailScreen extends ConsumerWidget {
  const DecisionDetailScreen({required this.decisionId, super.key});

  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Decision> detail = ref.watch(
      decisionDetailProvider(decisionId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decision'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.invalidate(decisionDetailProvider(decisionId));
              ref.invalidate(decisionsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh decision',
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(_errorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (Decision decision) =>
            _DecisionDetailBody(decisionId: decisionId, decision: decision),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return switch (error) {
    DecisionNotFoundException() => 'This decision could not be found.',
    _ => 'Unable to load this decision.',
  };
}

class _DecisionDetailBody extends ConsumerWidget {
  const _DecisionDetailBody({required this.decisionId, required this.decision});

  final String decisionId;
  final Decision decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(appClockProvider)();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _SummaryCard(decision: decision, now: now),
        const SizedBox(height: AppSpacing.md),
        _ContextCard(decision: decision),
        const SizedBox(height: AppSpacing.md),
        _ActionsCard(decisionId: decisionId, decision: decision),
        const SizedBox(height: AppSpacing.md),
        _DiscussionCard(decisionId: decisionId, discussion: decision.discussion),
        const SizedBox(height: AppSpacing.md),
        _AuditTrailCard(auditTrail: decision.auditTrail),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.decision, required this.now});

  final Decision decision;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final bool isCritical = decision.urgency == DecisionUrgency.critical;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                      size: 18,
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
            Text(decision.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                DecisionBadge(icon: AppIcons.status, text: decision.state.label),
                DecisionBadge(icon: Icons.shield_outlined, text: decision.risk.label),
                DecisionBadge(
                  icon: AppIcons.stale,
                  text: describeDeadline(decision.deadline, now),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Requested by ${decision.requestedBy} · ${UtcMoment.day(decision.requestedAt)}',
              style: operationalText.metadata,
            ),
            Text('Project: ${decision.projectId}', style: operationalText.metadata),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.decision});

  final Decision decision;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (decision.context.isNotEmpty) ...<Widget>[
              Text(decision.context, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
            ],
            _Section(title: 'Impact', body: decision.impactSummary),
            _Section(title: 'Recommendation', body: decision.recommendationSummary),
            if (decision.riskDetails.isNotEmpty)
              _BulletSection(title: 'Risks', items: decision.riskDetails),
            if (decision.evidence.isNotEmpty)
              _BulletSection(title: 'Evidence', items: decision.evidence),
            if (decision.affectedEntities.isNotEmpty)
              _BulletSection(
                title: 'Affected entities',
                items: decision.affectedEntities,
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text('• $item', style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.decisionId, required this.decision});

  final String decisionId;
  final Decision decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isPending = decision.state == DecisionState.pending;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!isPending)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'This decision was already ${decision.state.label.toLowerCase()}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (isPending) ...<Widget>[
                  FilledButton(
                    key: const Key('decisionApproveButton'),
                    onPressed: () => _openResolutionDialog(
                      context,
                      ref,
                      actionLabel: 'Approve',
                      commentLabel: 'Comment (optional)',
                      commentRequired: false,
                      onSubmit: (String comment) => ref
                          .read(decisionRepositoryProvider)
                          .approve(decisionId, comment: comment.isEmpty ? null : comment),
                    ),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    key: const Key('decisionRejectButton'),
                    onPressed: () => _openResolutionDialog(
                      context,
                      ref,
                      actionLabel: 'Reject',
                      commentLabel: 'Justification (required)',
                      commentRequired: true,
                      onSubmit: (String comment) => ref
                          .read(decisionRepositoryProvider)
                          .reject(decisionId, justification: comment),
                    ),
                    child: const Text('Reject'),
                  ),
                  OutlinedButton(
                    key: const Key('decisionRequestRevisionButton'),
                    onPressed: () => _openResolutionDialog(
                      context,
                      ref,
                      actionLabel: 'Request revision',
                      commentLabel: 'What needs revising (required)',
                      commentRequired: true,
                      onSubmit: (String comment) => ref
                          .read(decisionRepositoryProvider)
                          .requestRevision(decisionId, comment: comment),
                    ),
                    child: const Text('Request revision'),
                  ),
                ],
                OutlinedButton(
                  key: const Key('decisionDiscussButton'),
                  onPressed: () => _openResolutionDialog(
                    context,
                    ref,
                    actionLabel: 'Discuss',
                    commentLabel: 'Comment (required)',
                    commentRequired: true,
                    requiresCriticalAcknowledgement: false,
                    onSubmit: (String comment) => ref
                        .read(decisionRepositoryProvider)
                        .discuss(decisionId, comment: comment),
                  ),
                  child: const Text('Discuss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResolutionDialog(
    BuildContext context,
    WidgetRef ref, {
    required String actionLabel,
    required String commentLabel,
    required bool commentRequired,
    required Future<Decision> Function(String comment) onSubmit,
    bool requiresCriticalAcknowledgement = true,
  }) async {
    final String? comment = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _ResolutionDialog(
        decision: decision,
        actionLabel: actionLabel,
        commentLabel: commentLabel,
        commentRequired: commentRequired,
        requiresCriticalAcknowledgement: requiresCriticalAcknowledgement,
      ),
    );
    if (comment == null) {
      return;
    }
    try {
      await onSubmit(comment);
      ref.invalidate(decisionDetailProvider(decisionId));
      ref.invalidate(decisionsProvider);
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

/// One dialog for every resolution/discuss action: a comment field (required
/// or optional per [commentRequired]) and, for a critical decision's
/// state-changing action, a checkbox naming this specific decision and
/// action — not a generic "Are you sure?" — that must be checked before the
/// submit button enables.
class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog({
    required this.decision,
    required this.actionLabel,
    required this.commentLabel,
    required this.commentRequired,
    required this.requiresCriticalAcknowledgement,
  });

  final Decision decision;
  final String actionLabel;
  final String commentLabel;
  final bool commentRequired;
  final bool requiresCriticalAcknowledgement;

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _acknowledged = false;

  bool get _isCritical =>
      widget.requiresCriticalAcknowledgement &&
      widget.decision.urgency == DecisionUrgency.critical;

  bool get _canSubmit =>
      (!widget.commentRequired || _controller.text.trim().isNotEmpty) &&
      (!_isCritical || _acknowledged);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.actionLabel} "${widget.decision.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('decisionResolutionCommentField'),
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: widget.commentLabel),
            onChanged: (String _) => setState(() {}),
          ),
          if (_isCritical)
            CheckboxListTile(
              key: const Key('decisionCriticalAcknowledgeCheckbox'),
              value: _acknowledged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? value) =>
                  setState(() => _acknowledged = value ?? false),
              title: Text(
                'I understand this will ${widget.actionLabel.toLowerCase()} the '
                'critical decision "${widget.decision.title}" and this cannot '
                'be undone from here.',
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('decisionResolutionSubmitButton'),
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard({required this.decisionId, required this.discussion});

  final String decisionId;
  final List<DecisionComment> discussion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Discussion', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (discussion.isEmpty)
              Text('No comments yet.', style: theme.textTheme.bodyMedium)
            else
              for (final DecisionComment comment in discussion)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${comment.author} · ${UtcMoment.minute(comment.postedAt)}',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(comment.body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AuditTrailCard extends StatelessWidget {
  const _AuditTrailCard({required this.auditTrail});

  final List<DecisionAuditEvent> auditTrail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Resolution history', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (auditTrail.isEmpty)
              Text('No resolution actions yet.', style: theme.textTheme.bodyMedium)
            else
              for (final DecisionAuditEvent event in auditTrail)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${event.action.label} by ${event.actor} · ${UtcMoment.minute(event.occurredAt)}',
                        style: theme.textTheme.labelMedium,
                      ),
                      if (event.comment case final String comment?)
                        Text(comment, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
