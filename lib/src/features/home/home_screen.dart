import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../catalog/catalog_screen.dart';
import '../inventory/inventory_screen.dart';
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shoppingCount = context
        .select<InventoryProvider, int>((p) => p.shoppingList.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: false,
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          CatalogScreen(),
          InventoryScreen(),
          ShoppingListScreen(),
          SettingsScreen(),
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
                icon: Badge(
                  isLabelVisible: shoppingCount > 0,
                  label: Text('$shoppingCount'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: shoppingCount > 0,
                  label: Text('$shoppingCount'),
                  child: const Icon(Icons.shopping_cart),
                ),
                label: l10n.tabShopping,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.tabSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
