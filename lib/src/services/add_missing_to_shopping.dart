import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../data/catalog_repository.dart';
import '../models/inventory_entry.dart';
import '../state/inventory_provider.dart';
import 'paint_matcher.dart';

/// Adds a project's missing paints to the shopping list — unless the shelf
/// already covers some of them, in which case the user decides.
///
/// Replaces three identical private copies (own recipe, public recipe,
/// paint list), which is also why the substitute-awareness lands in all
/// three places at once.
///
/// The choice dialog only appears when the choice EXISTS: if nothing
/// missing has a stand-in, this stays the one-tap action it always was —
/// an empty dialog would be friction spent on nothing. When it does
/// appear, the money-saving option leads, and adding everything remains
/// one tap away: a substitute is a suggestion, not a decree.
Future<void> addMissingToShopping(
  BuildContext context,
  Iterable<String> paintIds,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final inventory = context.read<InventoryProvider>();
  final catalog = context.read<CatalogRepository>();

  // Only paints with no entry at all need adding; low and wishlisted ones
  // are already on the shopping list.
  final missing = paintIds
      .where((paintId) => inventory.statusOf(paintId) == null)
      .toList();

  final ownedIds = {
    for (final e in inventory.entries.values)
      if (e.status == PaintStatus.inStock || e.status == PaintStatus.low)
        e.paintId,
  };
  final substitutable = missing.where((paintId) {
    final paint = catalog.byId(paintId);
    if (paint == null) return false;
    return shelfSubstitutes(catalog, ownedIds, paint, limit: 1).isNotEmpty;
  }).toSet();

  var toAdd = missing;
  if (substitutable.isNotEmpty && substitutable.length < missing.length) {
    final onlyNeeded = missing.where((p) => !substitutable.contains(p));
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shoppingChoiceTitle),
        content: Text(l10n.shoppingChoiceBody(substitutable.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.shoppingChoiceAll(missing.length)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shoppingChoiceOnlyNeeded(onlyNeeded.length)),
          ),
        ],
      ),
    );
    if (choice == null) return; // dismissed: add nothing
    if (choice) toAdd = onlyNeeded.toList();
  } else if (substitutable.isNotEmpty && substitutable.length == missing.length) {
    // EVERYTHING missing has a stand-in. Still offer the purchase — the
    // user asked to buy — but say what the shelf already covers.
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shoppingChoiceTitle),
        content: Text(l10n.shoppingChoiceBody(substitutable.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.shoppingChoiceAll(missing.length)),
          ),
        ],
      ),
    );
    if (choice == null) return;
  }

  // One batched write, not one per paint.
  await inventory.setStatusForAll(toAdd, PaintStatus.wishlist);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.listAddedToShopping(toAdd.length))),
  );
}
