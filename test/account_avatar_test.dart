import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/widgets/account_avatar.dart';

/// The avatar is the only way into Settings from the app bar, so its fallback
/// behaviour is load-bearing: an account without a picture, or a picture that
/// fails to load, must never leave that control blank.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('an account with no photo shows the fallback', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountAvatar(
          photoUrl: null,
          fallback: Icon(Icons.settings_outlined),
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an account with a photo renders it', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountAvatar(
          photoUrl: 'https://example.test/avatar.png',
          fallback: Icon(Icons.settings_outlined),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a photo that fails to load falls back instead of going blank',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountAvatar(
          photoUrl: 'https://example.test/avatar.png',
          fallback: Icon(Icons.settings_outlined),
        ),
      ),
    );
    // flutter_test's default HttpClient rejects every request, so this
    // exercises the real errorBuilder path.
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('size is honoured so the app bar and Settings can differ',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountAvatar(
          photoUrl: 'https://example.test/avatar.png',
          fallback: Icon(Icons.settings_outlined),
          size: 40,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 40);
    expect(image.height, 40);
  });
}
