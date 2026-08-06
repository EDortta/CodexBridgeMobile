@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Executable enforcement of the layering documented in
/// `docs/architecture/state-architecture.md`.
///
/// Until 2026-08-06 that layering existed only as prose. The council round of
/// that date found that the next feature screen could add
/// `import '../../../app/app_shell.dart';` and merge green: `flutter analyze`,
/// `flutter test` and the whole CI job would pass while the one-way boundary
/// silently became false. `AppRoutes` and `AppDestination` were deliberately
/// left in `lib/core/navigation/` for exactly this reason — this test is what
/// keeps that decision from being undone by accident.
void main() {
  final Directory lib = Directory('lib');

  test('no lower layer imports the app/ composition root', () {
    final List<String> violations = <String>[];

    for (final File file in _dartFilesUnder(lib)) {
      final String path = file.path;
      final bool isLowerLayer =
          path.startsWith('lib/features/') || path.startsWith('lib/core/');
      if (!isLowerLayer) {
        continue;
      }

      for (final _Import import in _importsOf(file)) {
        final bool reachesApp =
            import.target.startsWith('package:codex_bridge_mobile/app/') ||
            _resolve(path, import.target).startsWith('lib/app/');
        if (reachesApp) {
          violations.add('$path:${import.line} -> ${import.target}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'features/ and core/ must not depend on app/. app/ composes them; '
          'a dependency in the other direction inverts the boundary and makes '
          'the composition root unavoidable for every feature.\n'
          '${violations.join('\n')}',
    );
  });

  test('no feature imports another feature', () {
    final List<String> violations = <String>[];
    final RegExp featureOf = RegExp(r'^lib/features/([^/]+)/');

    for (final File file in _dartFilesUnder(lib)) {
      final String path = file.path;
      final RegExpMatch? owner = featureOf.firstMatch(path);
      if (owner == null) {
        continue;
      }

      for (final _Import import in _importsOf(file)) {
        final String target = import.target.startsWith('package:')
            ? import.target.replaceFirst('package:codex_bridge_mobile/', 'lib/')
            : _resolve(path, import.target);
        final RegExpMatch? reached = featureOf.firstMatch(target);
        if (reached != null && reached.group(1) != owner.group(1)) {
          violations.add('$path:${import.line} -> ${import.target}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'features are siblings: they share through core/, never directly. '
          'A direct import couples two features and makes either unusable '
          'without the other.\n${violations.join('\n')}',
    );
  });
}

class _Import {
  const _Import(this.target, this.line);

  final String target;
  final int line;
}

Iterable<File> _dartFilesUnder(Directory directory) sync* {
  for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}

final RegExp _importPattern = RegExp('''^\\s*import\\s+['"]([^'"]+)['"]''');

Iterable<_Import> _importsOf(File file) sync* {
  final List<String> lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? match = _importPattern.firstMatch(lines[i]);
    if (match != null) {
      yield _Import(match.group(1)!, i + 1);
    }
  }
}

/// Resolves a relative import against the importing file, so `../../../app/x`
/// is compared as `lib/app/x` rather than by spelling.
String _resolve(String fromPath, String target) {
  if (target.startsWith('package:') || target.startsWith('dart:')) {
    return target;
  }
  final List<String> segments = fromPath.split('/')..removeLast();
  for (final String part in target.split('/')) {
    if (part == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
    } else if (part != '.') {
      segments.add(part);
    }
  }
  return segments.join('/');
}
