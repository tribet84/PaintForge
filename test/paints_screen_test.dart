import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/features/paints/paints_screen.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/paint.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/widgets/shelf_starter.dart';
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

  late FakeInventoryRepository lastRepository;

  Future<InventoryProvider> pumpPaints(
    WidgetTester tester, {
    Map<String, PaintStatus> owned = const {},
    bool skipStarter = true,
  }) async {
    final repository = FakeInventoryRepository();
    lastRepository = repository;
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
    // An empty shelf now opens on the guided starter. Most tests here are
    // about the regular catalogue, so skip it by default; starter tests pass
    // skipStarter: false and meet it deliberately.
    if (skipStarter && find.byType(ShelfStarter).evaluate().isNotEmpty) {
      await tester.tap(find.text("I'd rather browse on my own"));
      await tester.pumpAndSettle();
    }
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

  testWidgets('range chips appear once a brand is picked and narrow the list',
      (tester) async {
    await pumpPaints(tester);

    // No brand selected: ranges collide across brands, so no range row yet.
    expect(find.text('All ranges'), findsNothing);

    await tester.tap(find.text('Vallejo'));
    await tester.pumpAndSettle();
    expect(find.text('All ranges'), findsOneWidget);

    await tester.tap(find.text('Game Color'));
    await tester.pumpAndSettle();

    final gameColor =
        catalog.search('', brand: PaintBrand.vallejo, range: 'Game Color');
    expect(find.text('${gameColor.length} paints'), findsOneWidget);
  });

  testWidgets('a search can never leave a range chip with an empty list',
      (tester) async {
    await pumpPaints(tester);

    await tester.tap(find.text('Vallejo'));
    await tester.pumpAndSettle();

    // 'wash' matches nothing in Xpress Color, so that chip must disappear
    // instead of offering an inexplicably empty subcategory.
    await tester.enterText(find.byType(TextField), 'wash');
    await tester.pumpAndSettle();
    expect(find.text('Xpress Color'), findsNothing);
    expect(find.text('Model Wash'), findsOneWidget);
  });

  testWidgets('a query that empties the selected range resets the filter',
      (tester) async {
    // Wide enough that the Xpress Color chip is on-screen and tappable —
    // the range row scrolls horizontally on a phone.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpPaints(tester);

    await tester.tap(find.text('Vallejo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xpress Color'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sepia wash');
    await tester.pumpAndSettle();

    // The Xpress filter is gone, so the wash that matches the query shows
    // instead of an empty list under a stale filter.
    expect(find.text('Sepia Wash'), findsOneWidget);
  });

  testWidgets('switching brand drops the old brand\'s range filter',
      (tester) async {
    await pumpPaints(tester);

    await tester.tap(find.text('Vallejo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Game Color'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Citadel'));
    await tester.pumpAndSettle();

    // A Vallejo range kept across the switch would show an empty list.
    final citadelCount =
        catalog.paints.where((p) => p.brand == PaintBrand.citadel).length;
    expect(find.text('$citadelCount paints'), findsOneWidget);
    expect(find.text('Game Color'), findsNothing);
  });

  testWidgets('search narrows the current scope', (tester) async {
    await pumpPaints(tester);

    await tester.enterText(find.byType(TextField), 'abaddon');
    await tester.pumpAndSettle();

    // Computed, not hard-coded: several ranges legitimately carry the same
    // paint name (Base and Air both have an Abaddon Black), and the catalog
    // keeps growing.
    final matches = catalog.search('abaddon');
    expect(matches, isNotEmpty);
    expect(
      find.text(matches.length == 1 ? '1 paint' : '${matches.length} paints'),
      findsOneWidget,
    );
    expect(find.text('Abaddon Black'), findsNWidgets(matches.length));
  });

  testWidgets(
      'a bulk action is ONE write, not one per paint',
      (tester) async {
    // The point of batching: N paints used to mean N round trips and N
    // billed operations. This fails loudly if the loop ever comes back.
    final repository = FakeInventoryRepository();
    lastRepository = repository;
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
    await tester.tap(find.text("I'd rather browse on my own"));
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

  testWidgets('the Mine count matches what the list actually shows',
      (tester) async {
    final real = catalog.paints.first;
    // A paint id that is no longer in the bundled catalogue used to inflate
    // the toggle's count, so it claimed more paints than it could ever show.
    await pumpPaints(tester, owned: {
      real.id: PaintStatus.inStock,
      'citadel-retired-paint-that-no-longer-exists': PaintStatus.inStock,
    });

    expect(find.text('Mine 1'), findsOneWidget);
    expect(find.text('1 paint'), findsOneWidget);
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
      final matches = catalog.search('abaddon');
      expect(find.text('${matches.length} selected'), findsOneWidget);

      await tester.tap(find.text('Owned'));
      await tester.pumpAndSettle();

      for (final paint in matches) {
        expect(inventory.statusOf(paint.id), PaintStatus.inStock);
      }
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

  group('shelf starter', () {
    // Five of the first eight sign-ups left with an empty shelf. The starter
    // is the answer, and these pin its contract: it greets an empty shelf,
    // one tap selects a pot, one button writes the lot in a single batch,
    // and it never traps anyone.
    testWidgets('greets an empty shelf instead of the 640-paint catalogue',
        (tester) async {
      await pumpPaints(tester, skipStarter: false);

      expect(find.byType(ShelfStarter), findsOneWidget);
      expect(find.byType(SegmentedButton<PaintScope>), findsNothing);
    });

    testWidgets('does not appear for a shelf that already has paints',
        (tester) async {
      await pumpPaints(
        tester,
        owned: {'citadel-abaddon-black': PaintStatus.inStock},
        skipStarter: false,
      );

      expect(find.byType(ShelfStarter), findsNothing);
    });

    testWidgets('adds the selection in ONE batched write', (tester) async {
      final inventory = await pumpPaints(tester, skipStarter: false);
      final repository = lastRepository;

      await tester.tap(find.text('Abaddon Black'));
      await tester.tap(find.text('Averland Sunset'));
      await tester.pump();
      await tester.tap(find.text('Add 2 paints to my shelf'));
      await tester.pumpAndSettle();

      expect(repository.writeCalls, 1,
          reason: 'a 30-pot first session must not be 30 round trips');
      // Not asserted by id: the grid may render the Air or the Base variant
      // of a name first. What matters is that exactly the two tapped pots
      // landed on the shelf as in-stock.
      expect(inventory.entries.length, 2);
      expect(
        inventory.entries.values.every((e) => e.status == PaintStatus.inStock),
        isTrue,
      );
      // The starter hands over to the regular catalogue once done.
      expect(find.byType(ShelfStarter), findsNothing);
    });

    testWidgets('walking away lands on the catalogue with nothing written',
        (tester) async {
      await pumpPaints(tester, skipStarter: false);
      final repository = lastRepository;

      await tester.tap(find.text("I'd rather browse on my own"));
      await tester.pumpAndSettle();

      expect(find.byType(ShelfStarter), findsNothing);
      expect(find.byType(SegmentedButton<PaintScope>), findsOneWidget);
      expect(repository.writeCalls, 0);
    });
  });
}
