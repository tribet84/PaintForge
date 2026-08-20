import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/widgets/recipe_section_card.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// The most expensive moment of following someone else's recipe is the
/// shopping list it implies. Each step should answer with the pot the
/// reader already owns before implying a purchase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  RecipeSection sectionUsing(String paintId) => RecipeSection(
        name: 'Armour',
        steps: [RecipeStep(title: 'Basecoat', paintId: paintId)],
      );

  Future<InventoryProvider> pumpCard(
    WidgetTester tester,
    RecipeSection section, {
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
            body: RecipeSectionCard(section: section, catalog: catalog),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return inventory;
  }

  testWidgets('a step whose paint you lack offers the pot you already own',
      (tester) async {
    // The recipe says Citadel's black; the reader owns Vallejo's.
    await pumpCard(
      tester,
      sectionUsing('citadel-abaddon-black'),
      owned: {'vallejo-70950-black': PaintStatus.inStock},
    );

    expect(find.textContaining('From your shelf'), findsOneWidget);
    expect(find.textContaining('Black'), findsWidgets);
  });

  testWidgets('a step whose paint you own suggests nothing', (tester) async {
    await pumpCard(
      tester,
      sectionUsing('citadel-abaddon-black'),
      owned: {'citadel-abaddon-black': PaintStatus.inStock},
    );

    expect(find.textContaining('From your shelf'), findsNothing,
        reason: 'the pot is on the shelf; there is nothing to substitute');
  });

  testWidgets('an empty shelf suggests nothing rather than a purchase',
      (tester) async {
    await pumpCard(tester, sectionUsing('citadel-abaddon-black'));

    expect(find.textContaining('From your shelf'), findsNothing);
  });

  testWidgets('marking the suggested pot as spent updates the hint in place',
      (tester) async {
    final inventory = await pumpCard(
      tester,
      sectionUsing('citadel-abaddon-black'),
      owned: {'vallejo-70950-black': PaintStatus.inStock},
    );
    expect(find.textContaining('From your shelf'), findsOneWidget);

    // The substitute leaves the shelf; the hint must not survive it.
    await inventory.remove('vallejo-70950-black');
    await tester.pumpAndSettle();

    expect(find.textContaining('From your shelf'), findsNothing);
  });
}
