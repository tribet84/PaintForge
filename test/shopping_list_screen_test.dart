import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/shopping/shopping_list_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Regression coverage for a real complaint: confirming several purchases in
/// quick succession queued one SnackBar per tap, which then played out one
/// after another for a long stretch after the user had already stopped
/// tapping. Purchases now go through ActionBatcher (test/action_batcher_test)
/// so rapid confirmations settle into a single summary.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<InventoryProvider> pumpShoppingList(
    WidgetTester tester, {
    required List<String> lowPaintIds,
    Duration purchaseFeedbackDebounce = const Duration(milliseconds: 30),
  }) async {
    final repository = FakeInventoryRepository();
    final inventory = InventoryProvider(repository: repository);
    addTearDown(inventory.dispose);
    for (final paintId in lowPaintIds) {
      await inventory.setStatus(paintId, PaintStatus.low);
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
          home: ShoppingListScreen(
            purchaseFeedbackDebounce: purchaseFeedbackDebounce,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return inventory;
  }

  /// Taps the first "Bought it" button and confirms the dialog. Used where
  /// the identity of the purchased paint does not matter to the assertion.
  Future<void> buyFirst(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Bought it').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // dialog opens
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // dialog closes
  }

  /// Buys a specific, named paint — used where a later assertion needs to
  /// know exactly which paint's name to expect.
  Future<void> buyPaintNamed(WidgetTester tester, String paintName) async {
    final tile = find.ancestor(
      of: find.text(paintName),
      matching: find.byType(ListTile),
    );
    final button = find.descendant(
      of: tile,
      matching: find.widgetWithText(FilledButton, 'Bought it'),
    );
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
      'confirming three purchases in a row shows exactly one summary '
      'SnackBar, not three', (tester) async {
    final paintIds = catalog.paints.take(3).map((p) => p.id).toList();
    // Each buyFirst() burns ~500ms of dialog-animation pumps, so the
    // debounce must outlast three of those back to back (~1.5s) or the
    // batch would settle mid-loop instead of after the last tap.
    const debounce = Duration(seconds: 2);
    await pumpShoppingList(
      tester,
      lowPaintIds: paintIds,
      purchaseFeedbackDebounce: debounce,
    );

    for (var i = 0; i < 3; i++) {
      await buyFirst(tester);
    }

    // Still within the debounce window: nothing shown yet, and never more
    // than one SnackBar regardless of how many purchases were confirmed.
    expect(find.byType(SnackBar).evaluate().length, lessThanOrEqualTo(1));

    await tester.pump(debounce + const Duration(milliseconds: 200));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('3 paints marked as bought'), findsOneWidget);
  });

  testWidgets('a single purchase names the paint instead of a generic count',
      (tester) async {
    final paint = catalog.paints.first;
    await pumpShoppingList(tester, lowPaintIds: [paint.id]);

    await buyFirst(tester);
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.textContaining(paint.name), findsOneWidget);
    expect(find.textContaining('marked as bought'), findsNothing);
  });

  testWidgets(
      'purchases spaced well apart do not accumulate into one batch',
      (tester) async {
    final paints = catalog.paints.take(2).toList();
    await pumpShoppingList(
      tester,
      lowPaintIds: paints.map((p) => p.id).toList(),
    );

    await buyPaintNamed(tester, paints[0].name);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('${paints[0].name} marked as owned'), findsOneWidget);

    // The first batch has settled; buying the other paint now is a later,
    // unrelated action and must not be folded into the first one's count.
    await tester.pump(const Duration(milliseconds: 200));
    await buyPaintNamed(tester, paints[1].name);
    // The first SnackBar is still showing, so clearSnackBars() plays its
    // exit animation before the second one can appear — give it time.
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('${paints[1].name} marked as owned'),
      findsOneWidget,
      reason: 'the second, later purchase must report on itself alone',
    );
    expect(find.textContaining('2 paints'), findsNothing);
  });

  testWidgets('mark-all-as-bought discards a pending single-purchase batch',
      (tester) async {
    final paints = catalog.paints.take(3).toList();
    const pendingDebounce = Duration(seconds: 3);
    await pumpShoppingList(
      tester,
      lowPaintIds: paints.map((p) => p.id).toList(),
      purchaseFeedbackDebounce: pendingDebounce,
    );

    // One individual purchase; with a 3s debounce and ~500ms of dialog
    // animation consumed, its batch is still pending when mark-all fires.
    await buyPaintNamed(tester, paints.first.name);

    await tester.tap(find.byTooltip('Mark all as bought'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('2 paints marked as bought'), findsOneWidget);

    // Scan across (and well past) where the discarded single-purchase batch
    // would have settled, in increments finer than a SnackBar's own ~4s
    // display duration — so a stale "<paint> marked as owned" toast can't
    // slip by unnoticed by appearing and auto-dismissing between checks.
    final staleMessage = find.text('${paints.first.name} marked as owned');
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(staleMessage, findsNothing);
    }
  });
}
