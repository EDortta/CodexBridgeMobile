import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../domain/live_session.dart';
import '../domain/live_session_repository.dart';
import 'live_session_providers.dart';

/// A live session card: state (never color alone), instruction, executor,
/// creation time, and the control actions its current state allows.
///
/// Extracted out of `work_screen.dart` (#24) once the project dashboard
/// became a second genuine consumer — the same "two callers" bar
/// `WorkSessionDetailScreen` was already extracted under.
class SessionCard extends ConsumerWidget {
  const SessionCard({required this.session, required this.busy, super.key});

  final LiveSession session;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final bool needsIntervention =
        session.state == LiveSessionState.awaitingApproval;

    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: needsIntervention
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
            width: needsIntervention ? 2 : 1,
          ),
          borderRadius: AppRadius.card,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () => context.go(
          Uri(
            path: AppDestination.work.detailPath,
            queryParameters: <String, String>{'session': session.id},
          ).toString(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (needsIntervention)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_rounded,
                        color: theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Needs your approval',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      session.projectId,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(session.state.label, style: operationalText.metadata),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(session.instruction, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Executor ${session.executorId}',
                style: operationalText.code,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Created ${UtcMoment.minute(session.createdAt)}',
                style: operationalText.metadata,
              ),
              if (session.lastError case final String error?) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  if (session.canPause)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.pause,
                              ),
                            ),
                      child: const Text('Pause'),
                    ),
                  if (session.canResume)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.resume,
                              ),
                            ),
                      child: const Text('Resume'),
                    ),
                  if (session.canRestart)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.restart,
                              ),
                            ),
                      child: const Text('Restart'),
                    ),
                  if (session.canStop)
                    FilledButton.tonal(
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              runSessionControlAction(
                                context,
                                ref,
                                session.id,
                                LiveSessionControlAction.stop,
                              ),
                            ),
                      child: Text(busy ? 'Sending…' : 'Stop'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
