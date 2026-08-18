import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/sample_recipe_seeder.dart';
import '../../services/share_links.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/account_avatar.dart';
import '../../widgets/banner_ad_widget.dart';
import '../lists/lists_screen.dart';
import '../paints/paints_screen.dart';
import '../recipes/public_recipe_screen.dart';
import '../recipes/recipes_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/shopping_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  /// Tabs the user has actually opened.
  ///
  /// Providers are lazy, so a tab that is never built never subscribes to
  /// Firestore and never costs a read. An IndexedStack builds every child up
  /// front, which quietly undid that: opening the app fetched lists and
  /// recipes even for someone who only came to tick off a paint.
  ///
  /// The set only grows, so a tab keeps its scroll position and state once
  /// visited — the reason to reach for IndexedStack in the first place.
  final _visited = <int>{0};

  static const _tabs = [PaintsScreen(), ListsScreen(), RecipesScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Seed the example recipe into brand-new accounts, in the UI language.
      context.read<SampleRecipeSeeder?>()?.seedIfNeeded(
            Localizations.localeOf(context).languageCode,
          );
      // If the app was opened through a shared-recipe link, show it now that
      // the user is signed in.
      final publishedId = PendingShareLink.consume();
      if (publishedId != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PublicRecipeScreen(
              publishedId: publishedId,
              fromSharedLink: true,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shoppingCount = context
        .select<InventoryProvider, int>((p) => p.shoppingList.length);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 32),
            const SizedBox(width: 8),
            Text(l10n.appTitle),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: l10n.tabShopping,
            icon: Badge(
              isLabelVisible: shoppingCount > 0,
              label: Text('$shoppingCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ShoppingListScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.tabSettings,
            // Google accounts carry a profile picture; showing it makes the
            // entry point read as "your account". Password accounts have no
            // picture, so they keep the plain settings gear.
            icon: AccountAvatar(
              photoUrl: context.read<AuthService>().photoUrl,
              fallback: const Icon(Icons.settings_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            // An unvisited tab renders nothing, so its provider is never
            // read and its Firestore listener never opens.
            if (_visited.contains(i)) _tabs[i] else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() {
              _index = value;
              _visited.add(value);
            }),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.palette_outlined),
                selectedIcon: const Icon(Icons.palette),
                label: l10n.tabPaints,
              ),
              NavigationDestination(
                icon: const Icon(Icons.checklist_rtl_outlined),
                selectedIcon: const Icon(Icons.checklist_rtl),
                label: l10n.tabLists,
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_stories_outlined),
                selectedIcon: const Icon(Icons.auto_stories),
                label: l10n.tabRecipes,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
