import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/operational_text_theme.dart';
import '../../../core/format/utc_moment.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/session.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// Signs this device in, shows the session it holds, and signs it out.
///
/// Nothing here renders a token. The screen shows *who* the session belongs to
/// and *how long* it lasts, which is what an operator needs to decide, and
/// neither of those is a secret.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  static const String title = 'Session';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: AsyncStateView<AuthState>(
        value: ref.watch(sessionProvider),
        data: (BuildContext context, AuthState state) => switch (state) {
          SignedOut() => _SignInForm(state: state),
          SignedIn() => _SessionDetails(state: state),
        },
      ),
    );
  }
}

/// Stateful only to own the username and password controllers.
///
/// Neither controller is ever seeded from state. The password is cleared as
/// soon as it has been handed to the gateway, so it does not sit in memory
/// behind a screen the operator has stopped looking at. The username is
/// deliberately left in place: it is not a secret, and keeping it lets an
/// operator who mistyped the password retry without retyping who they are.
class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm({required this.state});

  final SignedOut state;

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SignedOut state = widget.state;
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(AppIcons.session),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                state.reason.message,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (state.sessionMayRemainOnDevice) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _StorageWarning(
            message: SignedOut.sessionMayRemainMessage,
            onRetry: () =>
                unawaited(ref.read(sessionProvider.notifier).signOut()),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _username,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _password,
          // The credential is masked and kept out of every keyboard convenience
          // that would otherwise copy it somewhere this app does not control.
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (String _) => _signIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            errorText: state.failure?.message,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: state.signingIn ? null : _signIn,
          child: const Text('Sign in'),
        ),
        if (state.signingIn) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  /// The controller reports through provider state, not through this future, so
  /// nothing here awaits it — `unawaited` says that on the page rather than
  /// leaving a dropped future for the next reader to wonder about.
  void _signIn() {
    final String username = _username.text;
    final String password = _password.text;
    _password.clear();
    unawaited(
      ref
          .read(sessionProvider.notifier)
          .signIn(username: username, password: password),
    );
  }
}

/// What the device could not do to its own keystore, and the way to try again.
///
/// A warning with no action is a dead end: the removal that failed is the same
/// removal [SessionController.signOut] performs, so the retry is one tap rather
/// than a sign-in the operator may not have a code for.
class _StorageWarning extends StatelessWidget {
  const _StorageWarning({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(AppIcons.warning, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Remove from this device'),
        ),
      ],
    );
  }
}

class _SessionDetails extends ConsumerWidget {
  const _SessionDetails({required this.state});

  final SignedIn state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = state.session;
    final DateTime now = ref.watch(sessionClockProvider)();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(AppIcons.session),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    session.operatorName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    session.operatorId,
                    style: Theme.of(
                      context,
                    ).extension<OperationalTextTheme>()?.code,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(label: 'Status', value: _statusOf(session, now)),
        _DetailRow(
          label: 'Session expires',
          value: UtcMoment.minute(session.expiresAt),
        ),
        _DetailRow(
          label: 'Renewable until',
          value: UtcMoment.minute(session.refreshExpiresAt),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: state.renewing
                    ? null
                    : () => unawaited(
                        ref.read(sessionProvider.notifier).renew(),
                      ),
                child: const Text('Renew session'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: state.renewing
                    ? null
                    : () => unawaited(
                        ref.read(sessionProvider.notifier).signOut(),
                      ),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
        if (state.renewing) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  static String _statusOf(Session session, DateTime now) {
    return switch (session.lifecycleAt(now)) {
      SessionLifecycle.active => 'Active.',
      SessionLifecycle.renewalDue =>
        'Due for renewal. It will renew on the next launch, or now.',
      // Unreachable while signed in — the controller never leaves an expired
      // session on screen — but named rather than defaulted, so adding a
      // lifecycle value fails here instead of rendering the wrong one.
      SessionLifecycle.expired => 'Expired.',
    };
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
