import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/paints/paints_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// The catalogue and "my paints" merged into one screen: same list, different
/// scope. These pin the behaviour that makes the merge safe — chiefly that a
/// user's short shelf is not buried under 400+ catalogue rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<InventoryProvider> pumpPaints(
    WidgetTester tester, {
    Map<String, PaintStatus> owned = const {},
  }) async {
    final repository = FakeInventoryRepository();
    final inventory = InventoryProvider(repository: repository);
    addTearDown(inventory.dispose);
    for (final entry in owned.entries) {
      await inventory.setStatus(entry.key, entry.value);
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
          home: const Scaffold(body: PaintsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return inventory;
  }

  testWidgets('an empty shelf opens on All — Mine would be a blank screen',
      (tester) async {
    await pumpPaints(tester);

    final segmented = tester.widget<SegmentedButton<PaintScope>>(
      find.byType(SegmentedButton<PaintScope>),
    );
    expect(segmented.selected, {PaintScope.all});
    expect(find.textContaining('paints'), findsWidgets);
  });

  testWidgets('owning paints opens on Mine, the shorter and more relevant list',
      (tester) async {
    final citadel = catalog.paints.firstWhere((p) => p.brandName == 'Citadel');
    await pumpPaints(tester, owned: {citadel.id: PaintStatus.inStock});

    final segmented = tester.widget<SegmentedButton<PaintScope>>(
      find.byType(SegmentedButton<PaintScope>),
    );
    expect(segmented.selected, {PaintScope.mine});
    expect(find.text(citadel.name), findsOneWidget);
    expect(find.text('1 paint'), findsOneWidget);
  });

  testWidgets('switching to All reveals paints the user does not own',
      (tester) async {
    final owned = catalog.paints.first;
    await pumpPaints(tester, owned: {owned.id: PaintStatus.inStock});

    expect(find.text('1 paint'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('${catalog.paints.length} paints'), findsOneWidget);
  });

  testWidgets('search narrows the current scope', (tester) async {
    await pumpPaints(tester);

    await tester.enterText(find.byType(TextField), 'abaddon');
    await tester.pumpAndSettle();

    expect(find.text('1 paint'), findsOneWidget);
    expect(find.text('Abaddon Black'), findsOneWidget);
  });

  testWidgets(
      'a bulk action is ONE write, not one per paint',
      (tester) async {
    // The point of batching: N paints used to mean N round trips and N
    // billed operations. This fails loudly if the loop ever comes back.
    final repository = FakeInventoryRepository();
    final inventory = InventoryProvider(repository: repository);
    addTearDown(inventory.dispose);

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
          home: const Scaffold(body: PaintsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'green');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owned'));
    await tester.pumpAndSettle();

    expect(
      inventory.entries.length,
      greaterThan(1),
      reason: 'the search must have matched several paints for this to prove '
          'anything',
    );
    expect(
      repository.writeCalls,
      1,
      reason: 'every selected paint must land in a single batched write',
    );
  });

  group('bulk selection', () {
    testWidgets('marking several paints at once updates every one of them',
        (tester) async {
      final inventory = await pumpPaints(tester);

      await tester.enterText(find.byType(TextField), 'abaddon');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Owned'));
      await tester.pumpAndSettle();

      final abaddon =
          catalog.paints.firstWhere((p) => p.name == 'Abaddon Black');
      expect(inventory.statusOf(abaddon.id), PaintStatus.inStock);
    });

    testWidgets('applying an action leaves selection mode', (tester) async {
      await pumpPaints(tester);

      await tester.enterText(find.byType(TextField), 'abaddon');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owned'));
      await tester.pumpAndSettle();

      expect(find.text('Select all'), findsNothing);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final inventory = await pumpPaints(tester);

      await tester.enterText(find.byType(TextField), 'abaddon');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(inventory.entries, isEmpty);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('bulk remove clears the paints from the inventory',
        (tester) async {
      final abaddon =
          catalog.paints.firstWhere((p) => p.name == 'Abaddon Black');
      final inventory =
          await pumpPaints(tester, owned: {abaddon.id: PaintStatus.inStock});

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      // The action row scrolls horizontally on a phone.
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(inventory.statusOf(abaddon.id), isNull);
    });
  });
}
