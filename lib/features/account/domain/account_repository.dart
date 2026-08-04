import 'account_profile.dart';

abstract interface class AccountRepository {
  Future<AccountProfile> loadProfile();
}
