import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart' as catalog;
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  List<(InventoryEntry, catalog.Paint)> _resolve(
    List<InventoryEntry> entries,
    CatalogRepository repository,
  ) {
    final resolved = entries
        .map((entry) => (entry, repository.byId(entry.paintId)))
        .where((pair) => pair.$2 != null)
        .map((pair) => (pair.$1, pair.$2!))
        .toList()
      ..sort((a, b) => a.$2.name.compareTo(b.$2.name));
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<CatalogRepository>();
    final inventory = context.watch<InventoryProvider>();

    final low = _resolve(inventory.runningLow, repository);
    final wishlist = _resolve(inventory.wishlist, repository);

    if (low.isEmpty && wishlist.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: l10n.shoppingEmptyTitle,
        body: l10n.shoppingEmptyBody,
      );
    }

    Widget section(
      String title,
      List<(InventoryEntry, catalog.Paint)> items,
    ) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final (entry, paint) in items)
            PaintTile(
              paint: paint,
              trailing: FilledButton.tonalIcon(
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.actionPurchased),
                onPressed: () => inventory.markPurchased(entry.paintId),
              ),
            ),
        ],
      );
    }

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              section(l10n.shoppingLowSection, low),
              section(l10n.shoppingWishlistSection, wishlist),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              tooltip: l10n.shoppingCopyTooltip,
              onPressed: () => _copyList(context, low, wishlist),
              child: const Icon(Icons.copy),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyList(
    BuildContext context,
    List<(InventoryEntry, catalog.Paint)> low,
    List<(InventoryEntry, catalog.Paint)> wishlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final buffer = StringBuffer();
    for (final (_, paint) in [...low, ...wishlist]) {
      buffer.writeln(
        '- ${paint.name} (${paint.brandName}'
        '${paint.code != null ? ' ${paint.code}' : ''})',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    messenger.showSnackBar(SnackBar(content: Text(l10n.shoppingCopied)));
  }
}
