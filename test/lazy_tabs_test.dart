import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/features/home/home_screen.dart';
import 'package:paintforge/src/services/auth_service.dart';
import 'package:paintforge/src/state/follows_provider.dart';
import 'package:paintforge/src/state/inventory_provider.dart';
import 'package:paintforge/src/state/paint_lists_provider.dart';
import 'package:paintforge/src/state/recipes_provider.dart';
import 'package:provider/provider.dart';

import 'package:paintforge/src/services/app_settings.dart';

import 'fakes.dart';

/// Opening the app used to fetch lists AND recipes even for someone who only
/// came to tick off a paint: providers are lazy, but IndexedStack built every
/// tab up front and so read them all. Each of those is a Firestore query the
/// user never asked for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  testWidgets('a tab subscribes to Firestore only once it is opened',
      (tester) async {
    final listRepository = FakePaintListRepository();
    final recipeRepository = FakeRecipeRepository();
    final published = FakePublishedRecipeRepository();

    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);

    final settings = await testAppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
          Provider<AuthService>.value(value: _StubAuthService()),
          Provider<PublishedRecipeRepository>.value(value: published),
          ChangeNotifierProvider<FollowsProvider>(
            create: (_) => FollowsProvider(repository: published),
          ),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
          // Left to build themselves, exactly as the real app does, so the
          // test measures when they are first READ.
          ChangeNotifierProvider<PaintListsProvider>(
            create: (_) => PaintListsProvider(repository: listRepository),
          ),
          ChangeNotifierProvider<RecipesProvider>(
            create: (_) => RecipesProvider(
              repository: recipeRepository,
              publishedRepository: published,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      recipeRepository.watchCalls,
      0,
      reason: 'landing on Paints must not query the recipe collection',
    );
    expect(
      listRepository.watchCalls,
      0,
      reason: 'landing on Paints must not query the paint lists',
    );

    // Open Recipes: now, and only now, it should ask Firestore.
    await tester.tap(find.text('Recipes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recipeRepository.watchCalls, 1);
    expect(
      listRepository.watchCalls,
      0,
      reason: 'opening Recipes must not drag the Lists tab along with it',
    );
  });

  testWidgets('a visited tab keeps its state when you come back',
      (tester) async {
    final recipeRepository = FakeRecipeRepository();
    final published = FakePublishedRecipeRepository();
    final inventory = InventoryProvider(repository: FakeInventoryRepository());
    addTearDown(inventory.dispose);

    final settings = await testAppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
          Provider<AuthService>.value(value: _StubAuthService()),
          Provider<PublishedRecipeRepository>.value(value: published),
          ChangeNotifierProvider<FollowsProvider>(
            create: (_) => FollowsProvider(repository: published),
          ),
          ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
          ChangeNotifierProvider<PaintListsProvider>(
            create: (_) =>
                PaintListsProvider(repository: FakePaintListRepository()),
          ),
          ChangeNotifierProvider<RecipesProvider>(
            create: (_) => RecipesProvider(
              repository: recipeRepository,
              publishedRepository: published,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Recipes'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Paints'));
    await tester.pump();
    await tester.tap(find.text('Recipes'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      recipeRepository.watchCalls,
      1,
      reason: 'coming back to a tab must reuse the live subscription, not '
          'pay for the same documents again',
    );
  });
}

/// HomeScreen only asks the auth service for a profile picture; everything
/// else here would be noise.
class _StubAuthService implements AuthService {
  @override
  String? get photoUrl => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
