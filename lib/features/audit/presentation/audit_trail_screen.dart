import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_event.dart';
import '../../../core/audit/audit_providers.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/presentation/async_state_view.dart';
import '../../../core/presentation/inline_badge.dart';

/// #46: the audit trail, read-only.
///
/// Deliberately offers nothing but a list: no edit, no delete, no clear —
/// "records are immutable from normal UI" is met by the store's interface
/// having no such operations (`core/audit/audit_trail_repository.dart`) and
/// by this screen not inventing any.
class AuditTrailScreen extends ConsumerWidget {
  const AuditTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit trail')),
      body: AsyncStateView<List<AuditEvent>>(
        value: ref.watch(auditEventsProvider),
        data: (BuildContext context, List<AuditEvent> events) {
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No sensitive operations have been recorded in this '
                  'app session yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: events.length,
            itemBuilder: (BuildContext context, int index) =>
                _AuditEventTile(event: events[index]),
          );
        },
      ),
    );
  }
}

class _AuditEventTile extends StatelessWidget {
  const _AuditEventTile({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      leading: Icon(switch (event.area) {
        AuditArea.decision => AppIcons.decisions,
        AuditArea.liveSession => AppIcons.terminal,
        AuditArea.mission => AppIcons.work,
        AuditArea.fileAccess => AppIcons.artifacts,
        AuditArea.installation => AppIcons.audit,
      }),
      title: Text('${event.area.label} — ${event.action} ${event.target}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${event.actor} · ${UtcMoment.minute(event.occurredAt)}'),
          if (event.failureReason != null)
            Text(
              event.failureReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          for (final MapEntry<String, String> entry in event.context.entries)
            Text('${entry.key}: ${entry.value}',
                style: theme.textTheme.bodySmall),
        ],
      ),
      trailing: InlineBadge(
        icon: switch (event.result) {
          AuditResult.success => AppIcons.status,
          AuditResult.failure => AppIcons.warning,
          AuditResult.cancelled => AppIcons.blocked,
        },
        text: event.result.label,
      ),
    );
  }
}
