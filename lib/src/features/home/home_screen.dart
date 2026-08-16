import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/sample_recipe_seeder.dart';
import '../../services/share_links.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/account_avatar.dart';
import '../../widgets/banner_ad_widget.dart';
import '../catalog/catalog_screen.dart';
import '../inventory/inventory_screen.dart';
import '../lists/lists_screen.dart';
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
            Icon(
              Icons.local_fire_department,
              color: Theme.of(context).colorScheme.primary,
            ),
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
        children: const [
          CatalogScreen(),
          InventoryScreen(),
          ListsScreen(),
          RecipesScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.search),
                label: l10n.tabCatalog,
              ),
              NavigationDestination(
                icon: const Icon(Icons.palette_outlined),
                selectedIcon: const Icon(Icons.palette),
                label: l10n.tabInventory,
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
