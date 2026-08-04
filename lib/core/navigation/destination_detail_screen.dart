import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_destinations.dart';

/// Placeholder detail route nested inside a destination's own navigator.
///
/// It exists so each destination has real navigation state to preserve across
/// destination switches; the real detail content lands with each feature.
class DestinationDetailScreen extends StatelessWidget {
  const DestinationDetailScreen({required this.destination, super.key});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('${destination.label} detail')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '${destination.label} detail placeholder',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
