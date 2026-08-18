import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/inventory_entry.dart';
import '../models/paint.dart';
import '../state/inventory_provider.dart';
import '../state/paint_lists_provider.dart';
import '../theme.dart';

/// Round swatch showing the paint color.
class PaintSwatch extends StatelessWidget {
  const PaintSwatch({super.key, required this.paint, this.size = 40});

  final Paint paint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = paint.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant, width: 2),
      ),
      // A paint we list but have no colour for says so, rather than passing
      // off a default grey as the real thing.
      child: color != null
          ? null
          : Icon(Icons.question_mark, size: size * 0.45, color: scheme.outline),
    );
  }
}

/// Small colored label for an inventory status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final PaintStatus status;

  /// Drops the wording and keeps the icon. Used where the row is already
  /// telling the user what the status is — repeating it in every row costs
  /// horizontal space and adds no information.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final (label, icon, color) = switch (status) {
      PaintStatus.inStock => (
          l10n.statusInStock,
          Icons.check_circle,
          StockColors.inStock(brightness),
        ),
      PaintStatus.low => (
          l10n.statusLow,
          Icons.hourglass_bottom,
          StockColors.low(brightness),
        ),
      PaintStatus.wishlist => (
          l10n.statusWishlist,
          Icons.shopping_cart,
          scheme.error,
        ),
    };
    if (compact) {
      // Still announced to screen readers, just not drawn.
      return Tooltip(
        message: label,
        child: Icon(icon, size: 18, color: color),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// List tile for a catalog paint; tapping opens the status action sheet.
class PaintTile extends StatelessWidget {
  const PaintTile({
    super.key,
    required this.paint,
    this.trailing,
    this.showBrand = true,
    this.compactStatus = false,
    this.showStatus = true,
  });

  final Paint paint;
  final Widget? trailing;

  /// Set false where the surrounding section is already a brand heading —
  /// repeating "Citadel" on every row under a "Citadel" header spends the
  /// subtitle on something the user already knows.
  final bool showBrand;

  /// Show the status as an icon rather than icon + wording.
  final bool compactStatus;

  /// Suppress the status entirely. Passing `trailing: null` does NOT do this
  /// — it falls through to the default chip — so screens that want a bare
  /// row have to say so explicitly.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final status = context
        .select<InventoryProvider, PaintStatus?>((p) => p.statusOf(paint.id));
    final subtitle = [
      if (showBrand) paint.brandName,
      paint.range,
      if (paint.code != null) paint.code!,
    ].join(' · ');
    return ListTile(
      // These lists are long — 400+ paints in the catalog — so the row is
      // tightened to fit noticeably more on screen while staying above the
      // 48px minimum touch target.
      dense: true,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 2,
      horizontalTitleGap: 12,
      leading: PaintSwatch(paint: paint, size: 36),
      title: Text(paint.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: trailing ??
          (!showStatus || status == null
              ? null
              : StatusChip(status: status, compact: compactStatus)),
      onTap: () => showPaintActions(context, paint),
    );
  }
}

/// Bottom sheet with the inventory actions for [paint].
Future<void> showPaintActions(BuildContext context, Paint paint) {
  final inventory = context.read<InventoryProvider>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final status = inventory.statusOf(paint.id);

      Widget option({
        required PaintStatus? value,
        required IconData icon,
        required String label,
      }) {
        final selected = status == value;
        return ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: selected ? const Icon(Icons.check) : null,
          selected: selected,
          onTap: () {
            if (value == null) {
              inventory.remove(paint.id);
            } else {
              inventory.setStatus(paint.id, value);
            }
            Navigator.of(sheetContext).pop();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: PaintSwatch(paint: paint, size: 48),
              title: Text(
                paint.name,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              subtitle: Text(
                [
                  paint.brandName,
                  paint.range,
                  if (paint.code != null) paint.code!,
                ].join(' · '),
              ),
            ),
            const Divider(height: 1),
            option(
              value: PaintStatus.inStock,
              icon: Icons.check_circle_outline,
              label: l10n.actionMarkInStock,
            ),
            option(
              value: PaintStatus.low,
              icon: Icons.hourglass_bottom,
              label: l10n.actionMarkLow,
            ),
            option(
              value: PaintStatus.wishlist,
              icon: Icons.add_shopping_cart,
              label: l10n.actionAddToShopping,
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(l10n.actionAddToList),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showAddToListSheet(context, paint);
              },
            ),
            if (status != null)
              option(
                value: null,
                icon: Icons.delete_outline,
                label: l10n.actionRemove,
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Bottom sheet to toggle [paint] in and out of the user's paint lists.
Future<void> showAddToListSheet(BuildContext context, Paint paint) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      // Watch, so the checkboxes reflect writes without closing the sheet.
      final lists = sheetContext.watch<PaintListsProvider>();

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: PaintSwatch(paint: paint, size: 40),
              title: Text(l10n.addToListTitle),
              subtitle: Text(paint.name),
            ),
            const Divider(height: 1),
            if (lists.lists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.addToListEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final list in lists.lists)
                      CheckboxListTile(
                        value: list.paintIds.contains(paint.id),
                        title: Text(list.name),
                        subtitle:
                            Text(l10n.listPaintCount(list.paintIds.length)),
                        onChanged: (value) {
                          if (value ?? false) {
                            lists.addPaint(list.id, paint.id);
                          } else {
                            lists.removePaint(list.id, paint.id);
                          }
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Shared empty-state placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Optional way out of the empty state, e.g. a button to clear whatever
  /// left the screen with nothing to show.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
