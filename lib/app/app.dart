import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_theme.dart';

/// Root widget of the application.
///
/// It owns only application-wide composition — theming and the router — and
/// holds no feature logic; `lib/app/` is the composition root, so a feature is
/// reached through the router and never by this widget directly.
class CodexBridgeMobileApp extends StatelessWidget {
  const CodexBridgeMobileApp({required this.router, super.key});

  /// Injected so tests can open the app on any deep-link path.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Codex Bridge Mobile',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
