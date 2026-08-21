import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/account_repository.dart';
import 'package:paintforge/src/features/settings/delete_account_flow.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:provider/provider.dart';

class FakeAuthService implements AuthService {
  var deleteCalled = false;
  var reauthCalled = false;

  /// Fresh by default so tests exercise the un-prompted path; a test that
  /// wants the up-front identity check sets this into the past.
  @override
  DateTime? lastSignInTime = DateTime.now();

  /// Makes the first deleteAccount() throw requires-recent-login, the way
  /// Firebase does for a session that has aged past its threshold.
  var failFirstDeleteWithStaleLogin = false;
  var _deleteAttempts = 0;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Stream<User?> userChanges() => const Stream.empty();

  @override
  User? get currentUser => null;

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
  Future<void> setPhotoUrl(String url) async {}

  @override
  List<String> providerIds = const ['password'];

  @override
  String? photoUrl;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    reauthCalled = true;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    reauthCalled = true;
  }

  @override
  Future<bool> hasAdminClaim() async => false;

  @override
  Future<void> deleteAccount() async {
    _deleteAttempts++;
    if (failFirstDeleteWithStaleLogin && _deleteAttempts == 1) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    deleteCalled = true;
  }
}

class FakeAccountRepository implements AccountRepository {
  var deleteAllCalled = false;

  @override
  Future<void> deleteAllData() async {
    deleteAllCalled = true;
  }
}

Widget wrap({
  required AuthService auth,
  required AccountRepository accountRepository,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: auth),
      Provider<AccountRepository>.value(value: accountRepository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => runDeleteAccountFlow(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('matchesDeleteConfirmation', () {
    test('exact match', () {
      expect(matchesDeleteConfirmation('DELETE', 'DELETE'), isTrue);
    });

    test('is case-insensitive', () {
      expect(matchesDeleteConfirmation('delete', 'DELETE'), isTrue);
    });

    test('ignores surrounding whitespace', () {
      expect(matchesDeleteConfirmation('  DELETE  ', 'DELETE'), isTrue);
    });

    test('rejects anything else', () {
      expect(matchesDeleteConfirmation('DELET', 'DELETE'), isFalse);
      expect(matchesDeleteConfirmation('', 'DELETE'), isFalse);
    });
  });

  group('runDeleteAccountFlow', () {
    testWidgets('delete button is disabled until the phrase matches',
        (tester) async {
      final auth = FakeAuthService();
      final repo = FakeAccountRepository();
      await tester.pumpWidget(wrap(auth: auth, accountRepository: repo));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final deleteButton =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete my account'));
      expect(deleteButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      final enabledButton =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete my account'));
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final auth = FakeAuthService();
      final repo = FakeAccountRepository();
      await tester.pumpWidget(wrap(auth: auth, accountRepository: repo));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleteAllCalled, isFalse);
      expect(auth.deleteCalled, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
        'an already-signed-in user is NOT asked to sign in again',
        (tester) async {
      final auth = FakeAuthService();
      final repo = FakeAccountRepository();
      await tester.pumpWidget(wrap(auth: auth, accountRepository: repo));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Confirm your identity'),
        findsNothing,
        reason: 'the session is fresh, so Firebase never demanded a re-login',
      );
      expect(auth.reauthCalled, isFalse);
      expect(repo.deleteAllCalled, isTrue);
      expect(auth.deleteCalled, isTrue);
    });

    testWidgets(
        'a stale session prompts to re-authenticate, then finishes the deletion',
        (tester) async {
      // Firebase only demands a fresh sign-in for aged sessions, and says so
      // by throwing requires-recent-login on the FIRST delete attempt.
      final auth = FakeAuthService()..failFirstDeleteWithStaleLogin = true;
      final repo = FakeAccountRepository();
      await tester.pumpWidget(wrap(auth: auth, accountRepository: repo));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your identity'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(auth.reauthCalled, isTrue);
      expect(repo.deleteAllCalled, isTrue);
      expect(auth.deleteCalled, isTrue);
    });

    testWidgets('data deletion runs before the account deletion, never after',
        (tester) async {
      final auth = FakeAuthService();
      final repo = FakeAccountRepository();
      final callOrder = <String>[];
      // Wrap both fakes to record ordering without changing their public API.
      final orderedRepo = _OrderedAccountRepository(repo, callOrder);
      final orderedAuth = _OrderedAuthService(auth, callOrder);

      await tester.pumpWidget(
        wrap(auth: orderedAuth, accountRepository: orderedRepo),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(
        callOrder,
        ['deleteAllData', 'deleteAccount'],
        reason: 'wiping the data first keeps the ID token those writes need',
      );
    });

      testWidgets(
          'a stale session confirms identity BEFORE any data is touched',
          (tester) async {
        // User-reported: the identity prompt used to land after the wipe, when
        // the deletion already felt finished. With a session known to be stale,
        // the prompt must come first — and cancelling it must leave every byte
        // of data intact.
        final auth = FakeAuthService()
          ..lastSignInTime = DateTime.now().subtract(const Duration(hours: 2));
        final repo = FakeAccountRepository();
        await tester.pumpWidget(wrap(auth: auth, accountRepository: repo));

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete my account'));
        await tester.pumpAndSettle();

        // The re-auth dialog is already up, and nothing has been deleted.
        expect(find.text('Confirm your identity'), findsOneWidget);
        expect(repo.deleteAllCalled, isFalse,
            reason: 'identity comes before destruction, not after');

        // Walking away from the prompt must abort the whole flow.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(repo.deleteAllCalled, isFalse);
        expect(auth.deleteCalled, isFalse);
      });
  });
}

class _OrderedAccountRepository implements AccountRepository {
  _OrderedAccountRepository(this._inner, this._order);
  final FakeAccountRepository _inner;
  final List<String> _order;

  @override
  Future<void> deleteAllData() async {
    _order.add('deleteAllData');
    await _inner.deleteAllData();
  }
}

class _OrderedAuthService implements AuthService {
  _OrderedAuthService(this._inner, this._order);
  final FakeAuthService _inner;
  final List<String> _order;

  @override
  Future<bool> hasAdminClaim() => _inner.hasAdminClaim();

  @override
  DateTime? get lastSignInTime => _inner.lastSignInTime;

  @override
  Future<void> setDisplayName(String name) => _inner.setDisplayName(name);

  @override
  Future<void> setPhotoUrl(String url) => _inner.setPhotoUrl(url);

  @override
  Stream<User?> authStateChanges() => _inner.authStateChanges();

  @override
  Stream<User?> userChanges() => _inner.userChanges();

  @override
  User? get currentUser => _inner.currentUser;

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _inner.signInWithEmail(email, password);

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _inner.registerWithEmail(email, password);

  @override
  Future<void> signInWithGoogle() => _inner.signInWithGoogle();

  @override
  Future<void> signOut() => _inner.signOut();

  @override
  List<String> get providerIds => _inner.providerIds;

  @override
  String? get photoUrl => _inner.photoUrl;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    _order.add('reauth');
    await _inner.reauthenticateWithPassword(password);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    _order.add('reauth');
    await _inner.reauthenticateWithGoogle();
  }

  @override
  Future<void> deleteAccount() async {
    _order.add('deleteAccount');
    await _inner.deleteAccount();
  }
}
