import 'package:flutter/material.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/operational_text_theme.dart';

class AppBootstrapScreen extends StatelessWidget {
  const AppBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OperationalTextTheme operationalText = theme
        .extension<OperationalTextTheme>()!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              elevation: AppElevation.card,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(AppIcons.terminal, color: theme.colorScheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Codex Bridge Mobile',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Terminal móvel', style: operationalText.metadata),
                    const SizedBox(height: AppSpacing.lg),
                    Text('codex bridge mobile', style: operationalText.code),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(
                          AppIcons.status,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '[ready] Local foundation active',
                          style: operationalText.log,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
