import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme.dart';
import 'features/app_bootstrap/app_bootstrap_screen.dart';

void main() => runApp(const ProviderScope(child: CodexBridgeMobileApp()));

class CodexBridgeMobileApp extends StatelessWidget {
  const CodexBridgeMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Codex Bridge Mobile',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppBootstrapScreen(),
    );
  }
}
