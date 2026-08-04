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

  /// Absolute path of a destination's detail route.
  static String detailOf(String destinationPath) =>
      '$destinationPath/$detailSegment';
}
