import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/inventory/inventory_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Regression coverage for making the summary discreet and adding a brand
/// filter, mirroring the Catalog tab's own filter chips.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<void> pumpInventory(
    WidgetTester tester, {
    required List<String> ownedPaintIds,
  }) async {
    final repository = FakeInventoryRepository();
    final inventory = InventoryProvider(repository: repository);
    addTearDown(inventory.dispose);
    for (final id in ownedPaintIds) {
      await inventory.setStatus(id, PaintStatus.inStock);
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
          home: const Scaffold(body: InventoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the summary has no card — it is a single discreet line',
      (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    await pumpInventory(tester, ownedPaintIds: [citadel.id]);

    expect(
      find.ancestor(of: find.byType(Text), matching: find.byType(Card)),
      findsNothing,
      reason: 'the total-count summary must not be wrapped in a Card anymore',
    );
    expect(find.textContaining('1 paint in your collection'), findsOneWidget);
  });

  testWidgets('a single-brand inventory shows no filter chips', (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    await pumpInventory(tester, ownedPaintIds: [citadel.id]);

    expect(
      find.byType(FilterChip),
      findsNothing,
      reason: 'filtering by brand is pointless with only one brand owned',
    );
  });

  testWidgets('owning paints from two brands shows chips for both',
      (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    final vallejo = catalog.paints.firstWhere((p) => p.brandName == 'Vallejo');
    await pumpInventory(tester, ownedPaintIds: [citadel.id, vallejo.id]);

    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Citadel'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Vallejo'), findsOneWidget);
    expect(find.text(citadel.name), findsOneWidget);
    expect(find.text(vallejo.name), findsOneWidget);
  });

  testWidgets('tapping a brand chip filters the list to that brand',
      (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    final vallejo = catalog.paints.firstWhere((p) => p.brandName == 'Vallejo');
    await pumpInventory(tester, ownedPaintIds: [citadel.id, vallejo.id]);

    await tester.tap(find.widgetWithText(FilterChip, 'Vallejo'));
    await tester.pumpAndSettle();

    expect(find.text(vallejo.name), findsOneWidget);
    expect(
      find.text(citadel.name),
      findsNothing,
      reason: 'selecting Vallejo must hide the Citadel paint',
    );
  });

  testWidgets('tapping the active brand chip again clears the filter',
      (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    final vallejo = catalog.paints.firstWhere((p) => p.brandName == 'Vallejo');
    await pumpInventory(tester, ownedPaintIds: [citadel.id, vallejo.id]);

    await tester.tap(find.widgetWithText(FilterChip, 'Vallejo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Vallejo'));
    await tester.pumpAndSettle();

    expect(find.text(citadel.name), findsOneWidget);
    expect(find.text(vallejo.name), findsOneWidget);
  });
}
