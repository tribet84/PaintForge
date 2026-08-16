import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/paint.dart';
import '../../models/paint_list.dart';
import '../../state/inventory_provider.dart';
import '../../state/paint_lists_provider.dart';
import '../../widgets/paint_list_widgets.dart';
import '../../widgets/paint_widgets.dart';
import '../../widgets/readiness_detail.dart';
import 'lists_screen.dart' show showListNameDialog;
import 'paint_picker_screen.dart';

/// One paint list: what it contains and whether it can be painted right now.
class PaintListDetailScreen extends StatelessWidget {
  const PaintListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lists = context.watch<PaintListsProvider>();
    final inventory = context.watch<InventoryProvider>();
    final catalog = context.read<CatalogRepository>();

    final list = lists.byId(listId);
    if (list == null) {
      // Deleted from another device while this screen was open.
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.delete_outline,
          title: l10n.listsDeleted,
          body: l10n.listsEmptyBody,
        ),
      );
    }

    final readiness = list.readiness(inventory.entries);
    final paints = list.paintIds
        .map(catalog.byId)
        .whereType<Paint>()
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'rename' => _rename(context, list),
              'delete' => _delete(context, list),
              _ => null,
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.listsRename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.listsDelete)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ReadinessHeader(readiness: readiness),
            const Divider(height: 1),
            Expanded(
              child: paints.isEmpty
                  ? EmptyState(
                      icon: Icons.format_paint_outlined,
                      title: l10n.listDetailEmptyTitle,
                      body: l10n.listDetailEmptyBody,
                    )
                  : ListView.builder(
                      // The "add missing to shopping" button stacks a second
                      // FAB on top of "add paints" when it's needed; without
                      // matching padding the last rows hide behind both.
                      padding: EdgeInsets.only(
                        bottom: readiness.needsShopping ? 160 : 96,
                      ),
                      itemCount: paints.length,
                      itemBuilder: (context, index) {
                        final paint = paints[index];
                        return Dismissible(
                          key: ValueKey(paint.id),
                          direction: DismissDirection.endToStart,
                          background: ColoredBox(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.only(right: 24),
                                child: Icon(Icons.delete_outline),
                              ),
                            ),
                          ),
                          onDismissed: (_) =>
                              _removePaint(context, list.id, paint.id),
                          child: PaintTile(paint: paint),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (readiness.needsShopping)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'list-to-shopping',
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                onPressed: () => _addMissingToShopping(context, list),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(l10n.listAddMissingToShopping),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'list-add-paints',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PaintPickerScreen(listId: list.id),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.listAddPaints),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, PaintList list) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<PaintListsProvider>();
    final name = await showListNameDialog(
      context,
      title: l10n.listsRename,
      initialValue: list.name,
    );
    if (name == null || name.isEmpty) return;
    await provider.rename(list.id, name);
  }

  Future<void> _delete(BuildContext context, PaintList list) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<PaintListsProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.listsDeleteConfirmTitle),
        content: Text(l10n.listsDeleteConfirmBody(list.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await provider.delete(list.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.listsDeleted)));
    navigator.pop();
  }

  Future<void> _removePaint(
    BuildContext context,
    String listId,
    String paintId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await context.read<PaintListsProvider>().removePaint(listId, paintId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.listPaintRemoved)));
  }

  /// Puts every paint of the list that is missing or running low on the
  /// shopping list, without touching the ones already well stocked.
  Future<void> _addMissingToShopping(
    BuildContext context,
    PaintList list,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();

    // Only paints with no entry at all need adding; low and wishlisted ones
    // are already on the shopping list. One batched write, not one per paint.
    final missing = list.paintIds
        .where((paintId) => inventory.statusOf(paintId) == null)
        .toList();
    await inventory.setStatusForAll(missing, PaintStatus.wishlist);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.listAddedToShopping(missing.length))),
    );
  }
}

class _ReadinessHeader extends StatelessWidget {
  const _ReadinessHeader({required this.readiness});

  final PaintListReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PaintListStatusChip(readiness: readiness),
              const Spacer(),
              Text(
                l10n.listPaintCount(readiness.total),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          PaintListReadinessBar(readiness: readiness),
          if (readiness.total > 0) ...[
            const SizedBox(height: 8),
            Text(
              readinessDetailText(l10n, readiness),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
