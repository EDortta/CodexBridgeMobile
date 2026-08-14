import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/account_profile.dart';
import 'account_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.account.label)),
      body: AsyncStateView<AccountProfile>(
        value: ref.watch(accountProfileProvider),
        data: (BuildContext context, AccountProfile profile) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            children: <Widget>[
              ListTile(
                leading: const Icon(AppIcons.account),
                title: Text(profile.operatorName),
                subtitle: Text(profile.session),
                onTap: () => context.go(AppDestination.account.detailPath),
              ),
              // Reached by path, not by importing the server or auth feature:
              // features are siblings and share through core/
              // (docs/architecture/state-architecture.md).
              ListTile(
                leading: const Icon(AppIcons.server),
                title: const Text('Codex Bridge server'),
                subtitle: const Text('Configure and test the gateway'),
                onTap: () => context.go(AppRoutes.server),
              ),
              ListTile(
                leading: const Icon(AppIcons.session),
                title: const Text('Session'),
                subtitle: const Text('Sign in, renew, or sign out'),
                onTap: () => context.go(AppRoutes.session),
              ),
            ],
          );
        },
      ),
    );
  }
}
