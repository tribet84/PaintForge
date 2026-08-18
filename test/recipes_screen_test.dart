import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/data/recipe_repository.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/widgets/brand_loader.dart';
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

  testWidgets('shows the loader while recipes are still arriving, not "no recipes"',
      (tester) async {
    final repository = _SilentRecipeRepository();
    final published = FakePublishedRecipeRepository();
    final recipes = RecipesProvider(
      repository: repository,
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BrandLoader), findsOneWidget);
    expect(
      find.text('No recipes yet'),
      findsNothing,
      reason: 'telling a painter they have no recipes before the backend '
          'has answered is a lie the screen used to tell',
    );

    // The backend finally answers, with nothing.
    repository.emit(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BrandLoader), findsNothing);
    expect(find.text('No recipes yet'), findsOneWidget);
  });
}

/// A provider is "loaded" only once its stream has spoken. Until then an
/// empty list means "we don't know yet", not "you have nothing" — and the
/// screen used to announce the latter, so a painter with a shelf full of
/// recipes was told they had none until Firestore answered.
class _SilentRecipeRepository implements RecipeRepository {
  final _controller = StreamController<List<Recipe>>();

  /// Lets the test decide when the backend finally answers.
  void emit(List<Recipe> recipes) => _controller.add(recipes);

  @override
  Stream<List<Recipe>> watchRecipes() => _controller.stream;

  @override
  Future<String> create(Recipe recipe) async => 'r1';
  @override
  Future<void> update(Recipe recipe) async {}
  @override
  Future<void> delete(String recipeId) async {}
}
