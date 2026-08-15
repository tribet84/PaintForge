import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/inventory_entry.dart';
import '../models/paint.dart';
import '../state/inventory_provider.dart';

/// Round swatch showing the paint color.
class PaintSwatch extends StatelessWidget {
  const PaintSwatch({super.key, required this.paint, this.size = 40});

  final Paint paint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: paint.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
    );
  }
}

/// Small colored label for an inventory status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final PaintStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      PaintStatus.inStock => (l10n.statusInStock, Icons.check_circle, scheme.primary),
      PaintStatus.low => (l10n.statusLow, Icons.hourglass_bottom, scheme.error),
      PaintStatus.wishlist => (l10n.statusWishlist, Icons.shopping_cart, scheme.tertiary),
    };
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
  const PaintTile({super.key, required this.paint, this.trailing});

  final Paint paint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = context
        .select<InventoryProvider, PaintStatus?>((p) => p.statusOf(paint.id));
    final subtitle = [
      paint.brandName,
      paint.range,
      if (paint.code != null) paint.code!,
    ].join(' · ');
    return ListTile(
      leading: PaintSwatch(paint: paint),
      title: Text(paint.name),
      subtitle: Text(subtitle),
      trailing: trailing ??
          (status == null ? null : StatusChip(status: status)),
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

/// Shared empty-state placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

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
          ],
        ),
      ),
    );
  }
}
