/// Local persistence of the operator's favorited project ids (#23).
///
/// Deliberately two methods wide, the same shape as
/// `core/storage/SecureKeyValueStore` — a policy interface backed by a
/// platform-agnostic store, testable with a fake that implements exactly what
/// the code under test calls (`design-standards.md` §2).
abstract interface class ProjectFavoritesStore {
  Future<Set<String>> readFavoriteIds();

  Future<void> writeFavoriteIds(Set<String> ids);
}
