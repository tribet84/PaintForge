import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/paint_list.dart';
import '../theme.dart';

/// Colour + label + icon for a list readiness verdict.
({String label, IconData icon, Color color}) paintListStatusStyle(
  BuildContext context,
  PaintListStatus status,
) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final brightness = Theme.of(context).brightness;
  return switch (status) {
    PaintListStatus.ready => (
        label: l10n.listStatusReady,
        icon: Icons.check_circle,
        color: StockColors.inStock(brightness),
      ),
    PaintListStatus.runningLow => (
        label: l10n.listStatusRunningLow,
        icon: Icons.hourglass_bottom,
        color: StockColors.low(brightness),
      ),
    PaintListStatus.incomplete => (
        label: l10n.listStatusIncomplete,
        icon: Icons.remove_shopping_cart,
        color: scheme.error,
      ),
    PaintListStatus.empty => (
        label: l10n.listStatusEmpty,
        icon: Icons.playlist_add,
        color: scheme.outline,
      ),
  };
}

/// Compact readiness badge for a paint list.
class PaintListStatusChip extends StatelessWidget {
  const PaintListStatusChip({super.key, required this.readiness});

  final PaintListReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final style = paintListStatusStyle(context, readiness.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, size: 16, color: style.color),
        const SizedBox(width: 4),
        Text(
          style.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: style.color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Progress bar showing owned / running low / missing proportions.
class PaintListReadinessBar extends StatelessWidget {
  const PaintListReadinessBar({super.key, required this.readiness});

  final PaintListReadiness readiness;

  @override
  Widget build(BuildContext context) {
    if (readiness.total == 0) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          // A childless ColoredBox given a loose height collapses to nothing,
          // and Row centres its children by default — which rendered this bar
          // at zero height. Stretching forces each segment to fill the 6px.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (readiness.inStock > 0)
              Expanded(
                flex: readiness.inStock,
                child: ColoredBox(color: StockColors.inStock(brightness)),
              ),
            if (readiness.low > 0)
              Expanded(
                flex: readiness.low,
                child: ColoredBox(color: StockColors.low(brightness)),
              ),
            if (readiness.missing > 0)
              Expanded(
                flex: readiness.missing,
                child: ColoredBox(color: StockColors.missing(brightness)),
              ),
          ],
        ),
      ),
    );
  }
}
