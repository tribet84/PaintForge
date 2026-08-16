import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/features/lists/lists_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/paint_lists_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// The Lists tab now shows ONLY the user's own paint lists — the built-in
/// shopping list moved to its own icon next to the avatar, so it must never
/// appear here.
class _Harness {
  _Harness()
      : inventoryRepository = FakeInventoryRepository(),
        listRepository = FakePaintListRepository() {
    inventory = InventoryProvider(repository: inventoryRepository);
    lists = PaintListsProvider(repository: listRepository);
  }

  final FakeInventoryRepository inventoryRepository;
  final FakePaintListRepository listRepository;
  late final InventoryProvider inventory;
  late final PaintListsProvider lists;

  void dispose() {
    inventory.dispose();
    lists.dispose();
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
          ChangeNotifierProvider<PaintListsProvider>.value(value: lists),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: ListsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('a brand-new account shows the empty state, not the shopping list',
      (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.text('No lists yet'), findsOneWidget);
    expect(
      find.text('Shopping list'),
      findsNothing,
      reason: 'the shopping list has its own icon now, not a place in Lists',
    );
  });

  testWidgets('a created list appears and the empty state goes away',
      (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await harness.listRepository.create('Ultramarines squad');
    await tester.pumpAndSettle();

    expect(find.text('Ultramarines squad'), findsOneWidget);
    expect(find.text('No lists yet'), findsNothing);
  });

  testWidgets('deleting the only list brings back the empty state',
      (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    final id = await harness.listRepository.create('Temporary');
    await tester.pumpAndSettle();
    expect(find.text('Temporary'), findsOneWidget);

    await harness.listRepository.delete(id);
    await tester.pumpAndSettle();

    expect(find.text('Temporary'), findsNothing);
    expect(find.text('No lists yet'), findsOneWidget);
  });

  testWidgets('paints marked as low or wishlisted do not create a list entry',
      (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await harness.inventory.setStatus('paint-a', PaintStatus.low);
    await harness.inventory.setStatus('paint-b', PaintStatus.wishlist);
    await tester.pumpAndSettle();

    expect(
      find.text('No lists yet'),
      findsOneWidget,
      reason: 'shopping-relevant inventory changes have nothing to do with '
          'the Lists tab anymore',
    );
  });
}
