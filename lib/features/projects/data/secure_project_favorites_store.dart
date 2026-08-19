import 'dart:convert';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/project_favorites_store.dart';

/// Remembers favorited project ids in platform secure storage.
///
/// Favorites are a convenience, not a secret or an audit-critical value, but
/// `core/storage` only exposes the one Keystore-backed seam
/// (`secure_key_value_store.dart`), and reusing it here is cheaper and safer
/// than adding a second local-storage dependency for one string. A read
/// failure fails **open** to "no favorites" rather than surfacing an error —
/// the opposite direction from `SecureSessionStore`/`SecureServerConfigStore`,
/// which fail closed on purpose because they guard identity and connectivity.
/// Losing the favorites list is an inconvenience; blocking the projects list
/// on it would not be proportionate.
class SecureProjectFavoritesStore implements ProjectFavoritesStore {
  const SecureProjectFavoritesStore(this._storage);

  final SecureKeyValueStore _storage;

  /// Namespaced like every other key sharing this store
  /// (`SecureServerConfigStore.selectedServerKey`, `SecureSessionStore.sessionKey`).
  static const String favoriteProjectIdsKey =
      'codex_bridge.favorite_project_ids';

  @override
  Future<Set<String>> readFavoriteIds() async {
    final String? stored;
    try {
      stored = await _storage.read(favoriteProjectIdsKey);
    } on Exception {
      return const <String>{};
    }
    if (stored == null) {
      return const <String>{};
    }

    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is! List) {
        return const <String>{};
      }
      return decoded.whereType<String>().toSet();
    } on FormatException {
      // A value written by an older or unrelated build reads as "no
      // favorites" rather than crashing the projects list over a string.
      return const <String>{};
    }
  }

  @override
  Future<void> writeFavoriteIds(Set<String> ids) {
    return _storage.write(favoriteProjectIdsKey, jsonEncode(ids.toList()));
  }
}
