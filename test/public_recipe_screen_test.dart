import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/features/recipes/public_recipe_screen.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/recipes_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Regression coverage for a real dead end: a subscriber opens a recipe they
/// had linked after the author unshared it, and the screen offered nothing
/// but a "not shared anymore" message — the dead bookmark stayed in their
/// account forever with no way to clear it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  Future<
      ({
        RecipesProvider recipes,
        FakePublishedRecipeRepository published,
      })> pumpScreen(
    WidgetTester tester, {
    required String publishedId,
    required bool linked,
  }) async {
    final published = FakePublishedRecipeRepository();
    if (linked) {
      published.seed(PublishedRecipe(
        id: publishedId,
        ownerUid: 'author-uid',
        authorName: 'Author',
        recipe: Recipe(
          id: publishedId,
          name: 'Necron Lord',
          updatedAt: DateTime(2026, 1, 1),
        ),
      ));
      await published.link(publishedId);
    }
    // The author unshares it AFTER the follower already linked — the exact
    // mismatch that leaves a dead entry behind.
    published.unpublishFromAuthorSide(publishedId);

    final recipes = RecipesProvider(
      repository: FakeRecipeRepository(),
      publishedRepository: published,
    );
    addTearDown(recipes.dispose);
    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          Provider<PublishedRecipeRepository>.value(value: published),
          ChangeNotifierProvider<RecipesProvider>.value(value: recipes),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          // A real route beneath the pushed screen, so "remove and go back"
          // has somewhere to go back TO — the app never opens this screen
          // as the very first page.
          home: const Scaffold(body: Text('Recipes list')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => PublicRecipeScreen(publishedId: publishedId),
    ));
    await tester.pumpAndSettle();

    return (recipes: recipes, published: published);
  }

  testWidgets('an unshared recipe still linked into the account offers to remove it',
      (tester) async {
    final state = await pumpScreen(tester, publishedId: 'pub-1', linked: true);

    expect(find.text('This recipe is not shared anymore'), findsOneWidget);
    expect(find.text('Remove bookmark'), findsOneWidget);

    await tester.tap(find.text('Remove bookmark'));
    await tester.pumpAndSettle();

    expect(state.recipes.isLinked('pub-1'), isFalse);
    expect(find.text('Removed from your bookmarks'), findsOneWidget);
  });

  testWidgets('an unshared recipe that was never linked offers nothing to remove',
      (tester) async {
    await pumpScreen(tester, publishedId: 'pub-2', linked: false);

    expect(find.text('This recipe is not shared anymore'), findsOneWidget);
    expect(find.text('Remove bookmark'), findsNothing);
  });
}
