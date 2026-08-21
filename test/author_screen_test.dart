import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/features/recipes/author_screen.dart';
import 'package:paintforge/src/features/recipes/public_recipe_screen.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:paintforge/src/state/follows_provider.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/recipes_provider.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// First rung of the social ladder: everything one author shares, reachable
/// only from a recipe someone already sent you. These pin the boundary that
/// makes it safe — the page shows what is published NOW, and only by the
/// author being viewed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  PublishedRecipe published(String id, String owner, String name, int day) =>
      PublishedRecipe(
        id: id,
        ownerUid: owner,
        authorName: owner == 'ana-uid' ? 'Ana' : 'Otro',
        recipe: Recipe(id: id, name: name, updatedAt: DateTime(2026, 1, day)),
      );

  Future<void> pumpAuthor(
    WidgetTester tester,
    FakePublishedRecipeRepository repository,
  ) async {
    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);
    final recipes = RecipesProvider(
      repository: FakeRecipeRepository(),
      publishedRepository: repository,
    );
    addTearDown(recipes.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          Provider<PublishedRecipeRepository>.value(value: repository),
          Provider<AuthService>.value(value: _StubAuthService()),
          ChangeNotifierProvider<FollowsProvider>(
            create: (_) => FollowsProvider(repository: repository),
          ),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
          ChangeNotifierProvider<RecipesProvider>.value(value: recipes),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AuthorScreen(ownerUid: 'ana-uid', authorName: 'Ana'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows the author's recipes, newest first, and nobody else's",
      (tester) async {
    final repository = FakePublishedRecipeRepository()
      ..seed(published('p1', 'ana-uid', 'Old Guard', 1))
      ..seed(published('p2', 'ana-uid', 'New Knight', 20))
      ..seed(published('p3', 'otro-uid', 'Not Hers', 10));

    await pumpAuthor(tester, repository);

    expect(find.text('Recipes by Ana'), findsOneWidget);
    expect(find.text('2 shared recipes'), findsOneWidget);
    expect(find.text('Not Hers'), findsNothing,
        reason: "another author's recipe on Ana's page would be a leak");

    final newY = tester.getTopLeft(find.text('New Knight')).dy;
    final oldY = tester.getTopLeft(find.text('Old Guard')).dy;
    expect(newY, lessThan(oldY), reason: 'newest first');
  });

  testWidgets('an unshared recipe is gone from the page too', (tester) async {
    // The privacy policy promises exactly this sentence.
    final repository = FakePublishedRecipeRepository()
      ..seed(published('p1', 'ana-uid', 'Kept', 1))
      ..seed(published('p2', 'ana-uid', 'Withdrawn', 2));
    repository.unpublishFromAuthorSide('p2');

    await pumpAuthor(tester, repository);

    expect(find.text('Kept'), findsOneWidget);
    expect(find.text('Withdrawn'), findsNothing);
  });

  testWidgets('tapping a recipe opens its public view', (tester) async {
    final repository = FakePublishedRecipeRepository()
      ..seed(published('p1', 'ana-uid', 'Necron Lord', 1));

    await pumpAuthor(tester, repository);
    await tester.tap(find.text('Necron Lord'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicRecipeScreen), findsOneWidget);
  });
}

/// The author screen only asks who the current user is.
class _StubAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
