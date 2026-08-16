import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/features/auth/login_screen.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:provider/provider.dart';

class FakeAuthService implements AuthService {
  String? signedInEmail;
  String? registeredEmail;
  bool googleUsed = false;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  Stream<User?> userChanges() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    signedInEmail = email;
  }

  @override
  Future<void> registerWithEmail(String email, String password) async {
    registeredEmail = email;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleUsed = true;
  }

  @override
  Future<void> signOut() async {}

  @override
  List<String> providerIds = const ['password'];

  @override
  String? photoUrl;

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteAccount() async {}
}

Widget wrap(AuthService auth) {
  return Provider<AuthService>.value(
    value: auth,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('validates empty fields before submitting', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Required field'), findsNWidgets(2));
    expect(auth.signedInEmail, isNull);
  });

  testWidgets('signs in with email and password', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'roberto@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(auth.signedInEmail, 'roberto@example.com');
    expect(auth.registeredEmail, isNull);
  });

  testWidgets('toggles to registration mode', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'new@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(auth.registeredEmail, 'new@example.com');
    expect(auth.signedInEmail, isNull);
  });

  testWidgets('google button delegates to the auth service', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    final googleButton = find.text('Continue with Google');
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(auth.googleUsed, isTrue);
  });
}
