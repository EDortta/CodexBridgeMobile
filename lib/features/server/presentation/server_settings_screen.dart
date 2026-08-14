import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/server_certificate.dart';
import '../domain/server_connection_report.dart';
import '../domain/server_probe_contract.dart';
import 'server_providers.dart';

/// Configures the Codex Bridge server and reports what a connection test found.
class ServerSettingsScreen extends ConsumerWidget {
  const ServerSettingsScreen({super.key});

  static const String title = 'Codex Bridge server';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: AsyncStateView<ServerSettings>(
        value: ref.watch(serverSettingsProvider),
        data: (BuildContext context, ServerSettings settings) =>
            _ServerSettingsForm(settings: settings),
      ),
    );
  }
}

/// Stateful only to own the text field's controller.
///
/// It is seeded once, in [initState], from the persisted selection — never
/// reassigned on a later rebuild, so a save or a connection test cannot
/// overwrite what the operator is in the middle of typing.
class _ServerSettingsForm extends ConsumerStatefulWidget {
  const _ServerSettingsForm({required this.settings});

  final ServerSettings settings;

  @override
  ConsumerState<_ServerSettingsForm> createState() => _ServerSettingsFormState();
}

class _ServerSettingsFormState extends ConsumerState<_ServerSettingsForm> {
  late final TextEditingController _url = TextEditingController(
    text: widget.settings.selectedServer?.toString() ?? '',
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ServerSettings settings = widget.settings;
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text(
          'The gateway this device talks to. It is stored in the device '
          'keystore and reused on the next launch.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://gateway.example.com',
            border: const OutlineInputBorder(),
            errorText: settings.rejection?.message,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: settings.testing ? null : _testConnection,
                child: const Text('Test connection'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: settings.testing ? null : _select,
                child: const Text('Save server'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SelectedServer(settings: settings),
        if (settings.testing) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
        if (settings.report != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _ConnectionReportCard(report: settings.report!),
        ],
      ],
    );
  }

  /// The controller reports through provider state, not through this future, so
  /// nothing here awaits it — `unawaited` says that on the page rather than
  /// leaving a dropped future for the next reader to wonder about.
  void _testConnection() {
    unawaited(
      ref.read(serverSettingsProvider.notifier).testConnection(_url.text),
    );
  }

  void _select() {
    unawaited(ref.read(serverSettingsProvider.notifier).select(_url.text));
  }
}

class _SelectedServer extends StatelessWidget {
  const _SelectedServer({required this.settings});

  final ServerSettings settings;

  @override
  Widget build(BuildContext context) {
    final OperationalTextTheme? operational = Theme.of(
      context,
    ).extension<OperationalTextTheme>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(AppIcons.server),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Selected server', style: operational?.metadata),
              Text(
                settings.selectedServer?.toString() ?? 'No server selected yet.',
                style: operational?.code,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders every fact the test established, and names the ones it did not.
///
/// A field that could not be determined says so explicitly instead of being
/// omitted: a missing row reads as "fine" and this screen exists to be read
/// under doubt.
class _ConnectionReportCard extends StatelessWidget {
  const _ConnectionReportCard({required this.report});

  final ServerConnectionReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = report.isReachable
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      elevation: AppElevation.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  report.isReachable ? AppIcons.status : AppIcons.unreachable,
                  color: tone,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    report.outcome.label,
                    style: theme.textTheme.titleMedium?.copyWith(color: tone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(report.detail, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _ReportRow(label: 'Latency', value: _latency(report)),
            _ReportRow(label: 'API version', value: _apiVersion(report)),
            _ReportRow(label: 'Certificate', value: _certificate(report)),
          ],
        ),
      ),
    );
  }

  static String _latency(ServerConnectionReport report) {
    final Duration? latency = report.latency;
    return latency == null
        ? 'Not measured — no response arrived.'
        : '${latency.inMilliseconds} ms to ${ServerProbeEndpoints.health}';
  }

  static String _apiVersion(ServerConnectionReport report) {
    final ServerApiVersion? version = report.apiVersion;
    if (version == null) {
      return 'Not reported — ${ServerProbeEndpoints.version} did not answer '
          'with a version body.';
    }
    final String build = version.buildRevision ?? 'not reported';
    return '${version.application} ${version.applicationVersion}\n'
        'API namespaces: ${version.apiVersions.join(', ')}\n'
        'Contract: ${version.contractVersion}\n'
        'Build: $build';
  }

  static String _certificate(ServerConnectionReport report) {
    final ServerCertificate? certificate = report.certificate;
    if (certificate == null) {
      return 'Not established — no TLS session was completed.';
    }
    return 'Subject: ${certificate.subject}\n'
        'Issuer: ${certificate.issuer}\n'
        'Valid: ${UtcMoment.day(certificate.validFrom)} to '
        '${UtcMoment.day(certificate.validTo)}';
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final OperationalTextTheme? operational = Theme.of(
      context,
    ).extension<OperationalTextTheme>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: operational?.metadata),
          Text(value, style: operational?.log),
        ],
      ),
    );
  }
}
