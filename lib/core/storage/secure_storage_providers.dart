import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flutter_secure_key_value_store.dart';
import 'secure_key_value_store.dart';

/// The one platform secure-storage handle in the application.
///
/// Shared rather than duplicated per feature so that overriding it in a test
/// replaces *every* secret path at once. Two providers would let a suite fake
/// one feature's storage and hit the real platform channel through the other.
final Provider<SecureKeyValueStore> secureKeyValueStoreProvider =
    Provider<SecureKeyValueStore>(
      (Ref ref) => const FlutterSecureKeyValueStore(),
    );
