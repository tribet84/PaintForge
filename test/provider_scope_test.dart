import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/state/paint_lists_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Screen that reads the provider from its own context, the way a pushed
/// route has to.
class _PushedScreen extends StatelessWidget {
  const _PushedScreen();

  @override
  Widget build(BuildContext context) {
    final lists = context.watch<PaintListsProvider>();
    return Scaffold(body: Text('lists: ${lists.lists.length}'));
  }
}

void main() {
  // Regression guard: the inventory and paint-list providers must sit ABOVE
  // MaterialApp. If they are placed inside `home:` they end up below the root
  // Navigator, and every pushed route or modal sheet throws
  // ProviderNotFoundException — something neither `flutter analyze` nor a
  // pure-Dart unit test can catch.
  testWidgets('pushed routes can read the paint lists provider',
      (tester) async {
    final provider =
        PaintListsProvider(repository: FakePaintListRepository());
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PaintListsProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _PushedScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('lists:'), findsOneWidget);
  });

  testWidgets('modal sheets can read the paint lists provider',
      (tester) async {
    final provider =
        PaintListsProvider(repository: FakePaintListRepository());
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PaintListsProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const _PushedScreen(),
                ),
                child: const Text('sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('lists:'), findsOneWidget);
  });
}
