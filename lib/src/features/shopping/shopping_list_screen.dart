import 'package:flutter/material.dart' hide Paint;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart';
import '../../services/action_batcher.dart';
import '../../services/shopping_list_formatter.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';
import '../../widgets/brand_loader.dart';

/// The built-in shopping list: every paint marked as running low or to buy.
///
/// Reached from the Lists tab, where it is pinned as the first entry. It is
/// derived from the inventory rather than stored, which is why it can never be
/// deleted or renamed.
class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({
    super.key,
    this.purchaseFeedbackDebounce = const Duration(milliseconds: 900),
  });

  /// How long to wait after the last confirmed purchase before showing the
  /// summary SnackBar. Exposed so widget tests can use a short value instead
  /// of depending on Material's animation-duration constants to stay under
  /// the real 900ms window.
  final Duration purchaseFeedbackDebounce;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  /// Confirming several purchases in quick succession must read as one
  /// event, not one queued SnackBar per tap — see ActionBatcher.
  late final ActionBatcher<String> _purchaseBatcher = ActionBatcher<String>(
    debounce: widget.purchaseFeedbackDebounce,
    onSettled: (count, lastPaintName) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? l10n.purchaseConfirmed(lastPaintName)
                : l10n.shoppingMarkAllDone(count),
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _purchaseBatcher.dispose();
    super.dispose();
  }

  List<(InventoryEntry, Paint)> _resolve(
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

    if (!inventory.loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabShopping)),
        body: const Center(child: BrandLoader()),
      );
    }

    if (low.isEmpty && wishlist.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabShopping)),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: l10n.shoppingEmptyTitle,
          body: l10n.shoppingEmptyBody,
        ),
      );
    }

    Widget section(String title, List<(InventoryEntry, Paint)> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final grouped = ShoppingListFormatter.groupByBrand(
        items.map((pair) => pair.$2).toList(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '$title (${items.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            for (final paint in entry.value)
              PaintTile(
                paint: paint,
                showBrand: false,
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.actionPurchased),
                  onPressed: () => _confirmPurchase(context, paint),
                ),
              ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabShopping),
        actions: [
          IconButton(
            tooltip: l10n.shoppingMarkAllBought,
            icon: const Icon(Icons.done_all),
            onPressed: () => _confirmMarkAllPurchased(context, low, wishlist),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            section(l10n.shoppingLowSection, low),
            section(l10n.shoppingWishlistSection, wishlist),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'shopping-copy',
            tooltip: l10n.shoppingCopyTooltip,
            onPressed: () => _copyList(context, low, wishlist),
            child: const Icon(Icons.copy),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'shopping-share',
            tooltip: l10n.shoppingShareTooltip,
            onPressed: () => _shareList(context, low, wishlist),
            child: const Icon(Icons.share),
          ),
        ],
      ),
    );
  }

  /// Confirms before the paint leaves the shopping list — a mistaken tap
  /// would otherwise silently rewrite its status. The resulting feedback goes
  /// through [_purchaseBatcher] rather than an immediate SnackBar, so
  /// confirming several paints in a row reads as one summary instead of a
  /// queue of toasts playing out one after another.
  Future<void> _confirmPurchase(BuildContext context, Paint paint) async {
    final l10n = AppLocalizations.of(context);
    final inventory = context.read<InventoryProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmPurchaseTitle),
        content: Text(l10n.confirmPurchaseBody(paint.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await inventory.markPurchased(paint.id);
    _purchaseBatcher.record(paint.name);
  }

  /// Bulk version of [_confirmPurchase] for the whole list at once — still
  /// gated behind a confirmation, since it is even easier to trigger by
  /// mistake than a single-paint tap.
  Future<void> _confirmMarkAllPurchased(
    BuildContext context,
    List<(InventoryEntry, Paint)> low,
    List<(InventoryEntry, Paint)> wishlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();
    final all = [...low, ...wishlist];
    if (all.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shoppingMarkAllConfirmTitle),
        content: Text(l10n.shoppingMarkAllConfirmBody(all.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // This action's own summary covers everything below; drop any
    // in-flight single-purchase batch so its delayed toast doesn't also fire
    // a few hundred milliseconds later, restating a subset of the same news.
    _purchaseBatcher.discard();

    await inventory.markAllPurchased(all.map((pair) => pair.$2.id));
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.shoppingMarkAllDone(all.length))),
    );
  }

  ShoppingListFormatter _formatter(AppLocalizations l10n) {
    return ShoppingListFormatter(
      ShoppingListLabels(
        title: l10n.shoppingListTitle,
        lowSection: l10n.shoppingLowSection,
        wishlistSection: l10n.shoppingWishlistSection,
        attribution: l10n.shoppingAttribution,
      ),
    );
  }

  String _render(
    AppLocalizations l10n,
    List<(InventoryEntry, Paint)> low,
    List<(InventoryEntry, Paint)> wishlist, {
    required bool includeAttribution,
  }) {
    return _formatter(l10n).format(
      low: low.map((pair) => pair.$2).toList(),
      wishlist: wishlist.map((pair) => pair.$2).toList(),
      includeAttribution: includeAttribution,
    );
  }

  Future<void> _copyList(
    BuildContext context,
    List<(InventoryEntry, Paint)> low,
    List<(InventoryEntry, Paint)> wishlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _render(l10n, low, wishlist, includeAttribution: true);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.shoppingCopied)));
  }

  Future<void> _shareList(
    BuildContext context,
    List<(InventoryEntry, Paint)> low,
    List<(InventoryEntry, Paint)> wishlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _render(l10n, low, wishlist, includeAttribution: true);

    try {
      // share_plus THROWS when the platform has no native share sheet to
      // hand off to (e.g. `navigator.canShare()` is false or missing) —
      // it does not silently do anything on its own. Only that case should
      // ever fall back to the clipboard below.
      await SharePlus.instance.share(
        ShareParams(text: text, subject: l10n.shoppingShareSubject),
      );
    } catch (_) {
      // No native share sheet available on this device/browser. Falling back
      // to the clipboard keeps the button useful, but with a message that
      // makes clear this ISN'T the same thing the copy button does on
      // purpose — otherwise the two buttons look identical when this path is
      // hit.
      await Clipboard.setData(ClipboardData(text: text));
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.shareFallbackCopied)),
      );
    }
  }
}
