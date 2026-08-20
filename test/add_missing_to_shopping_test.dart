import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/services/add_missing_to_shopping.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// "Add what's missing" now respects the shelf: paints with a close stand-in
/// among the user's pots are offered as savings, not silently bought. And
/// when no stand-in exists the button stays what it always was — one tap,
/// no dialog, because a choice with one option is not a choice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<InventoryProvider> pump(
    WidgetTester tester,
    List<String> projectPaints, {
    Map<String, PaintStatus> owned = const {},
  }) async {
    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);
    for (final e in owned.entries) {
      await inventory.setStatus(e.key, e.value);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => addMissingToShopping(context, projectPaints),
                child: const Text('add missing'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return inventory;
  }

  testWidgets('no stand-ins: one tap, everything added, no dialog',
      (tester) async {
    final inventory = await pump(
      tester,
      ['citadel-mephiston-red', 'citadel-macragge-blue'],
    );

    await tester.tap(find.text('add missing'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'a choice with one option is not a choice');
    expect(inventory.statusOf('citadel-mephiston-red'), PaintStatus.wishlist);
    expect(inventory.statusOf('citadel-macragge-blue'), PaintStatus.wishlist);
  });

  testWidgets('mixed: choosing the savings skips what the shelf covers',
      (tester) async {
    // The black has a stand-in (Vallejo's black is owned); the red has none.
    final inventory = await pump(
      tester,
      ['citadel-abaddon-black', 'citadel-mephiston-red'],
      owned: {'vallejo-70950-black': PaintStatus.inStock},
    );

    await tester.tap(find.text('add missing'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.textContaining('Add only the 1 without'));
    await tester.pumpAndSettle();

    expect(inventory.statusOf('citadel-mephiston-red'), PaintStatus.wishlist);
    expect(inventory.statusOf('citadel-abaddon-black'), isNull,
        reason: 'the shelf already covers it; buying it was declined');
  });

  testWidgets('mixed: adding all remains one tap away', (tester) async {
    final inventory = await pump(
      tester,
      ['citadel-abaddon-black', 'citadel-mephiston-red'],
      owned: {'vallejo-70950-black': PaintStatus.inStock},
    );

    await tester.tap(find.text('add missing'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add all 2'));
    await tester.pumpAndSettle();

    expect(inventory.statusOf('citadel-abaddon-black'), PaintStatus.wishlist);
    expect(inventory.statusOf('citadel-mephiston-red'), PaintStatus.wishlist);
  });

  testWidgets('dismissing the dialog buys nothing', (tester) async {
    final inventory = await pump(
      tester,
      ['citadel-abaddon-black', 'citadel-mephiston-red'],
      owned: {'vallejo-70950-black': PaintStatus.inStock},
    );

    await tester.tap(find.text('add missing'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // fuera del dialogo
    await tester.pumpAndSettle();

    expect(inventory.statusOf('citadel-abaddon-black'), isNull);
    expect(inventory.statusOf('citadel-mephiston-red'), isNull);
  });

  testWidgets('already low or wishlisted paints are never re-added',
      (tester) async {
    final repository = FakeInventoryRepository();
    final inventory = InventoryProvider(repository: repository);
    addTearDown(inventory.dispose);
    await inventory.setStatus('citadel-mephiston-red', PaintStatus.low);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => addMissingToShopping(
                    context, const ['citadel-mephiston-red']),
                child: const Text('add missing'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('add missing'));
    await tester.pumpAndSettle();

    expect(inventory.statusOf('citadel-mephiston-red'), PaintStatus.low,
        reason: 'a pot marked running low must not be demoted to wishlist');
  });
}
