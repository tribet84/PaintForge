import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/inventory_entry.dart';
import '../models/paint.dart';
import '../state/inventory_provider.dart';
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


/// The two-toggle control that replaced the five-option action sheet.
///
/// The insight came from the app's own community: a painter browsing the
/// catalogue only ever asks two things of a pot — do I have it, do I want
/// it. Everything the old sheet offered reduces to those two switches:
///
///   have ✓ alone        → in stock
///   want 🛒 alone        → on the shopping list
///   both together        → running low: I have it AND I need more
///   neither              → not owned
///
/// "Running low" stops being an option to hunt for in a menu and becomes
/// the natural consequence of switching both on. The readiness verdict and
/// the shopping list's urgency grouping — both built on that third state —
/// survive untouched.
class StatusToggles extends StatelessWidget {
  const StatusToggles({super.key, required this.paint});

  final Paint paint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final inventory = context.read<InventoryProvider>();
    final status = context
        .select<InventoryProvider, PaintStatus?>((p) => p.statusOf(paint.id));

    final hasIt =
        status == PaintStatus.inStock || status == PaintStatus.low;
    final wantsIt =
        status == PaintStatus.wishlist || status == PaintStatus.low;
    // When both are on the pot is running low; amber on both icons reads as
    // one combined state rather than two coincidences.
    final lowTint = StockColors.low(brightness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          isSelected: hasIt,
          tooltip: l10n.statusInStock,
          icon: const Icon(Icons.check_circle_outline),
          selectedIcon: Icon(
            Icons.check_circle,
            color: status == PaintStatus.low
                ? lowTint
                : StockColors.inStock(brightness),
          ),
          onPressed: () => inventory.toggleHave(paint.id),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          isSelected: wantsIt,
          tooltip: l10n.statusWishlist,
          icon: const Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(
            Icons.shopping_cart,
            color: status == PaintStatus.low ? lowTint : scheme.error,
          ),
          onPressed: () => inventory.toggleWant(paint.id),
        ),
      ],
    );
  }
}

/// List tile for a catalog paint.
class PaintTile extends StatelessWidget {
  const PaintTile({
    super.key,
    required this.paint,
    this.trailing,
    this.showBrand = true,
    this.showStatus = true,
    this.onTap,
  });

  final Paint paint;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Set false where the surrounding section is already a brand heading —
  /// repeating "Citadel" on every row under a "Citadel" header spends the
  /// subtitle on something the user already knows.
  final bool showBrand;

  /// Suppress the toggles entirely. Passing `trailing: null` does NOT do
  /// this — it falls through to the default toggles — so screens that want
  /// a bare row have to say so explicitly.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final status = context
        .select<InventoryProvider, PaintStatus?>((p) => p.statusOf(paint.id));
    final subtitle = [
      if (showBrand) paint.brandName,
      paint.range,
      if (paint.code != null) paint.code!,
    ].join(' · ');
    // The status is written out, not just toggled: on a phone there is no
    // hover and no tooltip, so the coloured word is what teaches a new user
    // what the two icons they just tapped actually mean.
    final (statusLabel, statusColor) = switch (status) {
      null => (null, null),
      PaintStatus.inStock => (
          l10n.statusInStock,
          StockColors.inStock(brightness)
        ),
      PaintStatus.low => (l10n.statusLow, StockColors.low(brightness)),
      PaintStatus.wishlist => (l10n.statusWishlist, scheme.error),
    };
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
      subtitle: Text.rich(
        TextSpan(
          text: subtitle,
          children: [
            if (showStatus && statusLabel != null)
              TextSpan(
                text: ' · $statusLabel',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing:
          trailing ?? (showStatus ? StatusToggles(paint: paint) : null),
      onTap: onTap,
    );
  }
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
