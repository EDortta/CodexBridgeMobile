import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../domain/live_session.dart';
import '../domain/live_session_explanation.dart';
import '../domain/live_session_log_entry.dart';
import '../domain/live_session_repository.dart';
import 'live_session_providers.dart';

class WorkSessionDetailScreen extends ConsumerWidget {
  const WorkSessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LiveSession> detail = ref.watch(
      liveSessionDetailProvider(sessionId),
    );
    final AsyncValue<List<LiveSessionLogEntry>> logs = ref.watch(
      liveSessionLogsProvider(sessionId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Session $sessionId'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ref.invalidate(liveSessionDetailProvider(sessionId));
              ref.invalidate(liveSessionLogsProvider(sessionId));
              ref.invalidate(remoteSessionsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh session',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _DetailCard(sessionId: sessionId, detail: detail),
          const SizedBox(height: AppSpacing.md),
          _LogsCard(logs: logs),
        ],
      ),
    );
  }
}

class _DetailCard extends ConsumerWidget {
  const _DetailCard({required this.sessionId, required this.detail});

  final String sessionId;
  final AsyncValue<LiveSession> detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) => Text(
            _errorMessage(error, fallback: 'Unable to load this session.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          data: (LiveSession session) => _SessionDetailBody(
            sessionId: sessionId,
            session: session,
          ),
        ),
      ),
    );
  }
}

class _SessionDetailBody extends ConsumerWidget {
  const _SessionDetailBody({required this.sessionId, required this.session});

  final String sessionId;
  final LiveSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;
    final RemoteSessionsState remoteState =
        ref.watch(remoteSessionsProvider).valueOrNull ?? const RemoteSessionsState();
    final bool busy = remoteState.pending.contains(session.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(session.projectId, style: theme.textTheme.titleLarge)),
            Text(session.state.label, style: operationalText.metadata),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(session.instruction, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        _DetailField(label: 'Session', value: sessionId),
        _DetailField(label: 'Executor', value: session.executorId),
        _DetailField(label: 'Priority', value: session.priority),
        if (session.requestedBy case final String requestedBy?)
          _DetailField(label: 'Requested by', value: requestedBy),
        _DetailField(
          label: 'Created',
          value: UtcMoment.minute(session.createdAt),
        ),
        if (session.startedAt case final DateTime startedAt)
          _DetailField(label: 'Started', value: UtcMoment.minute(startedAt)),
        if (session.completedAt case final DateTime completedAt)
          _DetailField(
            label: 'Completed',
            value: UtcMoment.minute(completedAt),
          ),
        if (session.lastError case final String error?) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: AppRadius.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _showExplanation(context, session.id),
                    child: const Text('Explain error'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (remoteState.error case final String error?) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
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
                        _runControl(
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
                        _runControl(
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
                        _runControl(
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
                        _runControl(
                          context,
                          ref,
                          session.id,
                          LiveSessionControlAction.stop,
                        ),
                      ),
                child: const Text('Stop'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _runControl(
    BuildContext context,
    WidgetRef ref,
    String targetSessionId,
    LiveSessionControlAction action,
  ) async {
    await runSessionControlAction(context, ref, targetSessionId, action);
    ref.invalidate(liveSessionDetailProvider(targetSessionId));
    ref.invalidate(liveSessionLogsProvider(targetSessionId));
    final String? error = ref.read(remoteSessionsProvider).valueOrNull?.error;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _showExplanation(BuildContext context, String targetSessionId) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _ExplanationDialog(sessionId: targetSessionId),
    );
  }
}

class _ExplanationDialog extends ConsumerWidget {
  const _ExplanationDialog({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LiveSessionErrorExplanation> explanation = ref.watch(
      liveSessionErrorExplanationProvider(sessionId),
    );
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return AlertDialog(
      title: const Text('Why this session failed'),
      content: SizedBox(
        width: double.maxFinite,
        child: explanation.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace _) => Text(
            _errorMessage(error, fallback: 'Unable to explain this session.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          data: (LiveSessionErrorExplanation report) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String reason in report.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text('• $reason', style: theme.textTheme.bodyMedium),
                  ),
                if (report.recentStderr.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Recent stderr', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  for (final LiveSessionLogEntry line in report.recentStderr)
                    SelectableText(line.line, style: operationalText.log),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _LogsCard extends StatefulWidget {
  const _LogsCard({required this.logs});

  final AsyncValue<List<LiveSessionLogEntry>> logs;

  @override
  State<_LogsCard> createState() => _LogsCardState();
}

class _LogsCardState extends State<_LogsCard> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Session logs', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: widget.logs.valueOrNull == null
                      ? null
                      : () => unawaited(
                          _copyAll(context, widget.logs.valueOrNull!),
                        ),
                  icon: const Icon(Icons.copy_all_rounded),
                  tooltip: 'Copy all log lines',
                ),
              ],
            ),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search logs',
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.md),
            widget.logs.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace _) => Text(
                _errorMessage(error, fallback: 'Unable to load session logs.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              data: (List<LiveSessionLogEntry> lines) {
                if (lines.isEmpty) {
                  return Text(
                    'No log lines are available for this session.',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                final String query = _query.trim().toLowerCase();
                final List<LiveSessionLogEntry> visible = query.isEmpty
                    ? lines
                    : lines
                          .where(
                            (LiveSessionLogEntry line) =>
                                line.line.toLowerCase().contains(query),
                          )
                          .toList(growable: false);
                if (visible.isEmpty) {
                  return Text(
                    'No log lines match "$_query".',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visible
                      .map(
                        (LiveSessionLogEntry line) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: SelectableText(
                            '[${line.stream}] ${line.line}',
                            style: operationalText.log,
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAll(
    BuildContext context,
    List<LiveSessionLogEntry> lines,
  ) async {
    final String text = lines
        .map((LiveSessionLogEntry line) => '[${line.stream}] ${line.line}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Log lines copied.')));
    }
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: <InlineSpan>[
            TextSpan(text: '$label: ', style: operationalText.metadata),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _errorMessage(Object error, {required String fallback}) {
  return switch (error) {
    LiveSessionRepositoryException(:final message) => message,
    _ => fallback,
  };
}
