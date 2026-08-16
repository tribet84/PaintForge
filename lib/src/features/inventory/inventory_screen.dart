import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart' as catalog;
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  catalog.PaintBrand? _brandFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<CatalogRepository>();
    final inventory = context.watch<InventoryProvider>();

    if (!inventory.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final owned = inventory.owned
        .map((entry) => (entry, repository.byId(entry.paintId)))
        .where((pair) => pair.$2 != null)
        .map((pair) => (pair.$1, pair.$2!))
        .toList();

    if (owned.isEmpty) {
      return EmptyState(
        icon: Icons.palette_outlined,
        title: l10n.inventoryEmptyTitle,
        body: l10n.inventoryEmptyBody,
      );
    }

    // Brand chips only ever offer brands the user actually owns something
    // from — filtering by a brand with nothing in it would be a dead end.
    final brandNames = <catalog.PaintBrand, String>{
      for (final (_, paint) in owned) paint.brand: paint.brandName,
    };
    if (_brandFilter != null && !brandNames.containsKey(_brandFilter)) {
      // The only owned paint of the selected brand was just removed.
      _brandFilter = null;
    }

    final visible = _brandFilter == null
        ? owned
        : owned.where((pair) => pair.$2.brand == _brandFilter).toList();

    // Group by brand, brands and paints alphabetically.
    final byBrand = <String, List<(InventoryEntry, catalog.Paint)>>{};
    for (final pair in visible) {
      byBrand.putIfAbsent(pair.$2.brandName, () => []).add(pair);
    }
    final sortedBrandNames = byBrand.keys.toList()..sort();
    for (final brand in sortedBrandNames) {
      byBrand[brand]!.sort((a, b) => a.$2.name.compareTo(b.$2.name));
    }

    final lowCount = inventory.runningLow.length;

    return SafeArea(
      child: Column(
        children: [
          // A single discreet line rather than a full card — this screen is
          // about the paints below it, not about restating their count.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.inventorySummary(owned.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (lowCount > 0)
                  Text(
                    l10n.inventoryLowCount(lowCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
              ],
            ),
          ),
          if (brandNames.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterChip(
                    label: Text(l10n.filterAllBrands),
                    selected: _brandFilter == null,
                    onSelected: (_) => setState(() => _brandFilter = null),
                  ),
                  for (final entry in brandNames.entries) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(entry.value),
                      selected: _brandFilter == entry.key,
                      onSelected: (_) => setState(
                        () => _brandFilter =
                            _brandFilter == entry.key ? null : entry.key,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final brand in sortedBrandNames) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      brand,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  for (final (entry, paint) in byBrand[brand]!)
                    PaintTile(
                      paint: paint,
                      showBrand: false,
                      // Everything on this screen is owned, so labelling each
                      // row "Owned" is noise; only the exceptions are shown.
                      showStatus: entry.status != PaintStatus.inStock,
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
