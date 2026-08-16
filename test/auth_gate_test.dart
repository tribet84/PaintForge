import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for a user-reported bug: "the sign out button does
/// nothing".
///
/// Settings is a PUSHED route, and the auth gate reacts to sign-out by
/// rebuilding with a different `home:`. Because MaterialApp is the same
/// widget type across both branches, Flutter updates it in place and the
/// Navigator KEEPS its route stack — so swapping `home:` only replaces the
/// route sitting *underneath* Settings, leaving the user staring at the very
/// screen they just signed out from.
///
/// Giving each auth branch a distinct key forces a fresh Navigator, which
/// discards the stale stack. These tests pin that behaviour by modelling the
/// gate's shape rather than depending on Firebase.
void main() {
  Widget buildGate({
    required Stream<String?> authState,
    required bool keyed,
  }) {
    Widget app({required Widget home, required String branch}) => MaterialApp(
          key: keyed ? ValueKey(branch) : null,
          home: home,
        );

    return StreamBuilder<String?>(
      stream: authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return app(home: const Text('loading'), branch: 'loading');
        }
        final uid = snapshot.data;
        if (uid == null) {
          return app(home: const Text('login'), branch: 'signed-out');
        }
        return app(
          branch: 'signed-in-$uid',
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: ElevatedButton(
                        // Stands in for AuthService.signOut(), whose only
                        // observable effect is the auth stream emitting null.
                        onPressed: () => _signOut(context),
                        child: const Text('sign out'),
                      ),
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        );
      },
    );
  }

  late StreamController<String?> authState;

  setUp(() => authState = StreamController<String?>.broadcast());
  tearDown(() => authState.close());

  Future<void> signInAndOpenSettings(WidgetTester tester) async {
    authState.add('uid-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('sign out'), findsOneWidget);
  }

  testWidgets('signing out from a pushed route reaches the login screen',
      (tester) async {
    _onSignOut = () => authState.add(null);
    await tester.pumpWidget(buildGate(authState: authState.stream, keyed: true));
    await signInAndOpenSettings(tester);

    await tester.tap(find.text('sign out'));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(
      find.text('sign out'),
      findsNothing,
      reason: 'the stale Settings route must not survive the sign-out',
    );
  });

  testWidgets(
      'without distinct keys the pushed route survives — the original bug',
      (tester) async {
    _onSignOut = () => authState.add(null);
    await tester.pumpWidget(
      buildGate(authState: authState.stream, keyed: false),
    );
    await signInAndOpenSettings(tester);

    await tester.tap(find.text('sign out'));
    await tester.pumpAndSettle();

    // Documents WHY the keys are load-bearing: drop them and this is what
    // the user sees — the button appears to do nothing at all.
    expect(find.text('sign out'), findsOneWidget);
    expect(find.text('login'), findsNothing);
  });
}

void Function()? _onSignOut;

void _signOut(BuildContext context) => _onSignOut?.call();
