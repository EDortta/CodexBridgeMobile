import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_account_repository.dart';
import '../domain/account_profile.dart';
import '../domain/account_repository.dart';

final Provider<AccountRepository> accountRepositoryProvider =
    Provider<AccountRepository>((Ref ref) => MockAccountRepository());

final FutureProvider<AccountProfile> accountProfileProvider =
    FutureProvider<AccountProfile>((Ref ref) async {
      return ref.watch(accountRepositoryProvider).loadProfile();
    });
