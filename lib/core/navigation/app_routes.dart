/// Canonical route paths for the application shell.
///
/// Every path is declared here so screens, the router, and deep-link tests
/// never spell a location by hand.
abstract final class AppRoutes {
  static const String projects = '/projects';
  static const String work = '/work';
  static const String conversations = '/conversations';
  static const String account = '/account';

  /// Cross-cutting entry point, hosted above the shell on the root navigator.
  static const String decisions = '/decisions';

  /// Relative segment of the detail route each destination nests under itself.
  static const String detailSegment = 'detail';

  /// Relative segment of the Codex Bridge server settings route.
  static const String serverSegment = 'server';

  /// Server settings, nested inside Account: configuring the gateway is part of
  /// setting this device up, so it keeps the Account branch's navigation stack
  /// instead of becoming a destination of its own.
  static const String server = '$account/$serverSegment';

  /// Absolute path of a destination's detail route.
  static String detailOf(String destinationPath) =>
      '$destinationPath/$detailSegment';
}
