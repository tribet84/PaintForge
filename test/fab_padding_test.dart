import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/lists/paint_list_detail_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/paint_lists_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Regression guard for a real bug reported with a screenshot: the last rows
/// of a list detail screen were hidden behind the stacked floating action
/// buttons, because the scroll view's bottom padding was a flat 96 regardless
/// of whether one or two buttons were actually showing. When the "add
/// missing to shopping" button appears on top of "add paints", the required
/// clearance roughly doubles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<double> pumpAndGetBottomPadding(
    WidgetTester tester, {
    required bool needsShopping,
  }) async {
    final inventoryRepository = FakeInventoryRepository();
    final listRepository = FakePaintListRepository();
    final inventory = InventoryProvider(repository: inventoryRepository);
    final lists = PaintListsProvider(repository: listRepository);
    addTearDown(inventory.dispose);
    addTearDown(lists.dispose);

    final paintId = catalog.paints.first.id;
    final listId = await listRepository.create('Test list', paintIds: [paintId]);
    if (needsShopping) {
      // Left with no inventory entry at all: readinessOf treats that as
      // "missing", which is exactly what needsShopping keys off.
    } else {
      await inventory.setStatus(paintId, PaintStatus.inStock);
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
          ChangeNotifierProvider<PaintListsProvider>.value(value: lists),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: PaintListDetailScreen(listId: listId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding as EdgeInsets;
    return padding.bottom;
  }

  testWidgets('extra bottom padding appears when the shopping FAB stacks up',
      (tester) async {
    final withoutShoppingButton =
        await pumpAndGetBottomPadding(tester, needsShopping: false);
    expect(withoutShoppingButton, 96);
  });

  testWidgets(
      'bottom padding grows to clear BOTH stacked FABs when shopping is needed',
      (tester) async {
    final withShoppingButton =
        await pumpAndGetBottomPadding(tester, needsShopping: true);
    expect(
      withShoppingButton,
      greaterThan(96),
      reason: 'a flat 96 was the actual bug: it only clears a single FAB, '
          'so the second one hides the last list rows behind it',
    );
    expect(withShoppingButton, 160);
  });
}
