import 'package:codex_bridge_mobile/core/storage/secure_storage_providers.dart';
import 'package:codex_bridge_mobile/features/projects/data/secure_project_favorites_store.dart';
import 'package:codex_bridge_mobile/features/projects/presentation/project_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_secure_key_value_store.dart';

void main() {
  ProviderContainer containerWith(InMemorySecureKeyValueStore storage) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        secureKeyValueStoreProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('toggling an id twice returns to no favorites', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    final ProviderContainer container = containerWith(storage);

    await container.read(projectFavoritesProvider.future);
    await container
        .read(projectFavoritesProvider.notifier)
        .toggle('codex-bridge-mobile');
    expect(
      container.read(projectFavoritesProvider).value,
      <String>{'codex-bridge-mobile'},
    );

    await container
        .read(projectFavoritesProvider.notifier)
        .toggle('codex-bridge-mobile');
    expect(container.read(projectFavoritesProvider).value, isEmpty);
  });

  test('a toggle persists to storage under the favorites key', () async {
    final InMemorySecureKeyValueStore storage = InMemorySecureKeyValueStore();
    final ProviderContainer container = containerWith(storage);

    await container.read(projectFavoritesProvider.future);
    await container
        .read(projectFavoritesProvider.notifier)
        .toggle('codex-bridge');

    expect(
      storage.entries[SecureProjectFavoritesStore.favoriteProjectIdsKey],
      '["codex-bridge"]',
    );
  });

  test(
    'a refused write rolls the optimistic update back, so a stuck star does not lie',
    () async {
      final InMemorySecureKeyValueStore storage =
          WriteRefusingSecureKeyValueStore();
      final ProviderContainer container = containerWith(storage);

      await container.read(projectFavoritesProvider.future);
      await container
          .read(projectFavoritesProvider.notifier)
          .toggle('codex-bridge');

      expect(container.read(projectFavoritesProvider).value, isEmpty);
    },
  );
}
