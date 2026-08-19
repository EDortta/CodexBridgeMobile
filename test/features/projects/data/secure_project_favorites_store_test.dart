import 'package:codex_bridge_mobile/features/projects/data/secure_project_favorites_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

/// Characterization of #23's local favorites persistence, mirroring the
/// style of `secure_server_config_store_test.dart`: pin the policy (key,
/// encoding, what an unreadable/corrupt value means) against a fake, since no
/// host-VM test can reach the real Keystore.
void main() {
  test('a favorited id is read back after the app is restarted', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    await SecureProjectFavoritesStore(storage).writeFavoriteIds(<String>{
      'codex-bridge-mobile',
    });

    final Set<String> restored = await SecureProjectFavoritesStore(
      storage,
    ).readFavoriteIds();

    expect(restored, <String>{'codex-bridge-mobile'});
  });

  test('favorites are stored under their own namespaced key', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();

    await SecureProjectFavoritesStore(
      storage,
    ).writeFavoriteIds(<String>{'a'});

    expect(storage.entries.keys, <String>[
      SecureProjectFavoritesStore.favoriteProjectIdsKey,
    ]);
  });

  test('nothing stored reads as no favorites, not as an error', () async {
    expect(
      await SecureProjectFavoritesStore(
        InMemorySecureKeyValueStore(),
      ).readFavoriteIds(),
      isEmpty,
    );
  });

  test('a keystore that cannot be read reads as no favorites', () async {
    // Unlike the session and server stores, favorites fail open on purpose —
    // losing them is an inconvenience, not a security or connectivity gap.
    expect(
      await SecureProjectFavoritesStore(
        const UnavailableSecureKeyValueStore(),
      ).readFavoriteIds(),
      isEmpty,
    );
  });

  test('a corrupt stored value reads as no favorites', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore(
      <String, String>{
        SecureProjectFavoritesStore.favoriteProjectIdsKey: 'not json',
      },
    );

    expect(
      await SecureProjectFavoritesStore(storage).readFavoriteIds(),
      isEmpty,
    );
  });

  test('a stored value that is not a JSON list reads as no favorites', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore(
      <String, String>{
        SecureProjectFavoritesStore.favoriteProjectIdsKey: '{"a":1}',
      },
    );

    expect(
      await SecureProjectFavoritesStore(storage).readFavoriteIds(),
      isEmpty,
    );
  });

  test('writing refuses through, so the caller knows the tap did not stick', () {
    expect(
      SecureProjectFavoritesStore(
        const UnavailableSecureKeyValueStore(),
      ).writeFavoriteIds(<String>{'a'}),
      throwsA(isA<Exception>()),
    );
  });
}
