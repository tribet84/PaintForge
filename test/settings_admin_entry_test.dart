import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/settings/settings_screen.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:provider/provider.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.admin = false});

  /// Whether this fake claims the signed-in user is a platform admin.
  final bool admin;

  @override
  Future<bool> hasAdminClaim() async => admin;

  @override
  User? get currentUser => null;

  @override
  DateTime? get lastSignInTime => null;

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
  Future<void> setDisplayName(String name) async {}

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

  Future<void> pumpSettings(WidgetTester tester, {required bool admin}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          Provider<AuthService>.value(value: FakeAuthService(admin: admin)),
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

  testWidgets('the admin entry shows for a user with the admin claim',
      (tester) async {
    await pumpSettings(tester, admin: true);
    expect(find.text('Admin panel'), findsOneWidget);
  });

  testWidgets('regular painters never see the admin entry', (tester) async {
    await pumpSettings(tester, admin: false);
    expect(find.text('Admin panel'), findsNothing);
  });
}
