import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart' as catalog;
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

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

    // Group by brand, brands and paints alphabetically.
    final byBrand = <String, List<(InventoryEntry, catalog.Paint)>>{};
    for (final pair in owned) {
      byBrand.putIfAbsent(pair.$2.brandName, () => []).add(pair);
    }
    final brandNames = byBrand.keys.toList()..sort();
    for (final brand in brandNames) {
      byBrand[brand]!.sort((a, b) => a.$2.name.compareTo(b.$2.name));
    }

    final lowCount = inventory.runningLow.length;

    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.inventorySummary(owned.length),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (lowCount > 0)
                            Text(
                              l10n.inventoryLowCount(lowCount),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final brand in brandNames) ...[
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
                trailing: StatusChip(status: entry.status),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
