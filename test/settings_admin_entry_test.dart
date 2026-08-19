import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/settings/settings_screen.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:provider/provider.dart';

/// Just enough of a firebase_auth [User] for the settings screen: an email
/// and its verification state. Everything else throws via noSuchMethod.
class FakeUser implements User {
  FakeUser({required String email, required bool emailVerified})
      : _email = email,
        _emailVerified = emailVerified;

  final String _email;
  final bool _emailVerified;

  @override
  String? get email => _email;

  @override
  bool get emailVerified => _emailVerified;

  @override
  String? get displayName => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  FakeAuthService({this.user});

  final User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Stream<User?> userChanges() => const Stream.empty();

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> registerWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  List<String> get providerIds => const ['password'];

  @override
  String? get photoUrl => null;

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<void> pumpSettings(WidgetTester tester, {User? user}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          Provider<AuthService>.value(value: FakeAuthService(user: user)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the admin entry shows for the verified admin account',
      (tester) async {
    await pumpSettings(
      tester,
      user: FakeUser(email: 'admin@example.com', emailVerified: true),
    );
    expect(find.text('Admin panel'), findsOneWidget);
  });

  testWidgets('regular painters never see the admin entry', (tester) async {
    await pumpSettings(
      tester,
      user: FakeUser(email: 'painter@example.com', emailVerified: true),
    );
    expect(find.text('Admin panel'), findsNothing);
  });

  testWidgets('an unverified copy of the admin address does not qualify',
      (tester) async {
    await pumpSettings(
      tester,
      user: FakeUser(email: 'admin@example.com', emailVerified: false),
    );
    expect(find.text('Admin panel'), findsNothing);
  });
}
