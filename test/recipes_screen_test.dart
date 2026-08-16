import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/features/recipes/recipes_screen.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/recipes_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// A linked recipe the author stopped sharing used to sit in the list
/// forever as a dead "not shared anymore" row with nothing to do about it.
/// It should be removable right there, without opening it first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a dead linked recipe can be removed straight from the list',
      (tester) async {
    final published = FakePublishedRecipeRepository();
    await published.link('pub-1'); // linked, but never published/seeded

    final recipes = RecipesProvider(
      repository: FakeRecipeRepository(),
      publishedRepository: published,
    );
    addTearDown(recipes.dispose);
    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PublishedRecipeRepository>.value(value: published),
          ChangeNotifierProvider<RecipesProvider>.value(value: recipes),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: RecipesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This recipe is not shared anymore'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(recipes.isLinked('pub-1'), isFalse);
    expect(find.text('This recipe is not shared anymore'), findsNothing);
  });
}
