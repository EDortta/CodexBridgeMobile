import 'package:flutter/material.dart';

void main() => runApp(const CodexBridgeMobileApp());

class CodexBridgeMobileApp extends StatelessWidget {
  const CodexBridgeMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Codex Bridge Mobile',
      home: Scaffold(body: Center(child: Text('Codex Bridge Mobile'))),
    );
  }
}
