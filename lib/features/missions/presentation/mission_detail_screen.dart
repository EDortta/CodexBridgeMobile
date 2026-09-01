import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audit/audit_event.dart';
import '../../../core/audit/audit_providers.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/relative_moment.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/presentation/inline_badge.dart';
import '../domain/mission.dart';
import '../domain/mission_control_action.dart';
import '../domain/mission_repository.dart';
import '../domain/mission_risk.dart';
import '../domain/mission_timeline_event.dart';
import 'mission_providers.dart';

/// #28: full context, dependencies, tests/files/artifacts, related
/// decisions, and the pause/resume/cancel/explain controls for one mission.
///
/// A blocked mission always shows its cause, never only implied by color —
/// the same rule `_MissionCard` (`work_screen.dart`) already follows. Cancel
/// — the only irreversible control here — always requires a reason and, for
/// a [MissionRisk.high] mission, an explicit acknowledgement, mirroring the
/// stronger, decision-specific confirmation `DecisionDetailScreen` built for
/// a critical decision rather than the plain Yes/No `runSessionControlAction`
/// uses for session stop/restart.
class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({required this.missionId, super.key});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Mission> detail = ref.watch(missionDetailProvider(missionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.invalidate(missionDetailProvider(missionId));
              ref.invalidate(missionsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh mission',
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
        data: (Mission mission) =>
            _MissionDetailBody(missionId: missionId, mission: mission),
      ),
    );
  }
}

String _errorMessage(Object error) {
  return switch (error) {
    MissionNotFoundException() => 'This mission could not be found.',
    _ => 'Unable to load this mission.',
  };
}

class _MissionDetailBody extends ConsumerWidget {
  const _MissionDetailBody({required this.missionId, required this.mission});

  final String missionId;
  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(appClockProvider)();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        _SummaryCard(mission: mission, now: now),
        const SizedBox(height: AppSpacing.md),
        if (mission.dependencies.isNotEmpty) ...<Widget>[
          _BulletCard(title: 'Dependencies', items: mission.dependencies),
          const SizedBox(height: AppSpacing.md),
        ],
        if (mission.tests.isNotEmpty ||
            mission.files.isNotEmpty ||
            mission.artifacts.isNotEmpty) ...<Widget>[
          _EvidenceCard(mission: mission),
          const SizedBox(height: AppSpacing.md),
        ],
        if (mission.relatedDecisionIds.isNotEmpty) ...<Widget>[
          _RelatedDecisionsCard(decisionIds: mission.relatedDecisionIds),
          const SizedBox(height: AppSpacing.md),
        ],
        _ActionsCard(missionId: missionId, mission: mission),
        const SizedBox(height: AppSpacing.md),
        _TimelineCard(timeline: mission.timeline),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.mission, required this.now});

  final Mission mission;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(mission.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                InlineBadge(icon: Icons.person_outline_rounded, text: mission.owner),
                InlineBadge(icon: Icons.timeline_rounded, text: mission.stage.label),
                InlineBadge(icon: Icons.shield_outlined, text: mission.risk.label),
                InlineBadge(icon: AppIcons.status, text: mission.state.label),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Project: ${mission.projectId}', style: operationalText.metadata),
            if (mission.objective.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text('Objective', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(mission.objective, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: mission.progress),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${(mission.progress * 100).round()}% · Started ${RelativeMoment.describe(mission.startedAt, now: now)}',
              style: operationalText.metadata,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(mission.latestEvent, style: theme.textTheme.bodyMedium),
            // A blocked mission always states its cause here, in text — the
            // state badge above never carries this alone (#28 acceptance
            // criterion: "o estado bloqueado inclui a causa").
            if (mission.blockedReason case final String reason?) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: AppRadius.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_rounded,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Blocked: $reason',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.title, required this.items});

  final String title;
  final List<String> items;

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
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text('• $item', style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (mission.tests.isNotEmpty) _Section(title: 'Tests', items: mission.tests),
            if (mission.files.isNotEmpty) _Section(title: 'Files', items: mission.files),
            if (mission.artifacts.isNotEmpty)
              _Section(title: 'Artifacts', items: mission.artifacts),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

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

class _RelatedDecisionsCard extends StatelessWidget {
  const _RelatedDecisionsCard({required this.decisionIds});

  final List<String> decisionIds;

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
            Text('Related decisions', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final String decisionId in decisionIds)
              InkWell(
                onTap: () => context.go(
                  Uri(
                    path: AppRoutes.decisionDetail,
                    queryParameters: <String, String>{'decision': decisionId},
                  ).toString(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Icon(AppIcons.decisions, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(decisionId, style: theme.textTheme.bodyMedium)),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.missionId, required this.mission});

  final String missionId;
  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mission.canPause && !mission.canResume && !mission.canCancel)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'This mission is ${mission.state.label.toLowerCase()} — no further controls apply.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (mission.canPause)
                  OutlinedButton(
                    key: const Key('missionPauseButton'),
                    onPressed: () => _run(context, ref, MissionControlAction.pause),
                    child: const Text('Pause'),
                  ),
                if (mission.canResume)
                  OutlinedButton(
                    key: const Key('missionResumeButton'),
                    onPressed: () => _run(context, ref, MissionControlAction.resume),
                    child: const Text('Resume'),
                  ),
                if (mission.canCancel)
                  FilledButton.tonal(
                    key: const Key('missionCancelButton'),
                    onPressed: () => _run(context, ref, MissionControlAction.cancel),
                    child: const Text('Cancel'),
                  ),
                OutlinedButton(
                  key: const Key('missionExplainButton'),
                  onPressed: () => _showExplanation(context),
                  child: const Text('Explain'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    MissionControlAction action,
  ) async {
    final AuditRecorder audit = ref.read(auditRecorderProvider);
    // Captured with the recorder, before the dialog's await: `ref.read` on
    // a consumer disposed while the dialog was up would drop a *confirmed*
    // cancel and its audit event with it (council 2026-08-26, the second
    // caller, round 2 — same shape fixed in `runSessionControlAction`).
    final MissionRepository repository = ref.read(missionRepositoryProvider);
    String? reason;
    if (action.requiresConfirmation) {
      reason = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => _CancelDialog(mission: mission),
      );
      if (reason == null) {
        // Backed out of the cancel dialog — recorded, not dropped (#46:
        // "failed and cancelled operations are included"). Pause/resume
        // have no confirmation step, so there is no back-out to record.
        await audit.record(
          area: AuditArea.mission,
          action: action.name,
          target: missionId,
          result: AuditResult.cancelled,
        );
        return;
      }
    }
    try {
      switch (action) {
        case MissionControlAction.pause:
          await repository.pause(missionId);
        case MissionControlAction.resume:
          await repository.resume(missionId);
        case MissionControlAction.cancel:
          await repository.cancel(missionId, reason: reason!);
      }
      // The flag, never the text: the cancel reason itself lands on the
      // mission's own timeline; the trail records that one was given.
      await audit.record(
        area: AuditArea.mission,
        action: action.name,
        target: missionId,
        result: AuditResult.success,
        context: <String, String>{
          if (action == MissionControlAction.cancel) 'reasonProvided': 'true',
        },
      );
      ref.invalidate(missionDetailProvider(missionId));
      ref.invalidate(missionsProvider);
    } on Exception catch (error) {
      await audit.record(
        area: AuditArea.mission,
        action: action.name,
        target: missionId,
        result: AuditResult.failure,
        failureReason: '$error',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _showExplanation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Why this mission is where it is'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String reason in mission.explanation)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('• $reason'),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Cancel is the only irreversible control on this screen, so it is the only
/// one that confirms — always with a required reason and, for a
/// [MissionRisk.high] mission, an explicit acknowledgement naming the
/// mission by title, the same escalation `_ResolutionDialog`
/// (`features/decisions/presentation/decision_detail_screen.dart`) applies
/// to a critical decision rather than a generic Yes/No dialog.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.mission});

  final Mission mission;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _acknowledged = false;

  bool get _isHighRisk => widget.mission.risk == MissionRisk.high;

  bool get _canSubmit =>
      _controller.text.trim().isNotEmpty && (!_isHighRisk || _acknowledged);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cancel "${widget.mission.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const Key('missionCancelReasonField'),
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (required)'),
            onChanged: (String _) => setState(() {}),
          ),
          if (_isHighRisk)
            CheckboxListTile(
              key: const Key('missionCancelAcknowledgeCheckbox'),
              value: _acknowledged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? value) => setState(() => _acknowledged = value ?? false),
              title: Text(
                'I understand this will cancel the high-risk mission '
                '"${widget.mission.title}" and this cannot be undone.',
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep mission'),
        ),
        FilledButton(
          key: const Key('missionCancelSubmitButton'),
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('Cancel mission'),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.timeline});

  final List<MissionTimelineEvent> timeline;

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
            Text('Timeline', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (timeline.isEmpty)
              Text('No transitions recorded yet.', style: theme.textTheme.bodyMedium)
            else
              for (final MissionTimelineEvent event in timeline)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${event.actor} · ${UtcMoment.minute(event.occurredAt)}',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(event.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
