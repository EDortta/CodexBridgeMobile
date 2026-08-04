import '../domain/account_profile.dart';
import '../domain/account_repository.dart';

class MockAccountRepository implements AccountRepository {
  @override
  Future<AccountProfile> loadProfile() {
    return Future<AccountProfile>.value(
      const AccountProfile(
        id: 'local-operator',
        operatorName: 'Local operator',
        session: 'Local session',
      ),
    );
  }
}
