import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/app_theme.dart';
import 'core/navigation/app_router.dart';

void main() => runApp(
  ProviderScope(child: CodexBridgeMobileApp(router: createAppRouter())),
);

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
