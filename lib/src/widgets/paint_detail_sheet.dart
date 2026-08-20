import 'package:flutter/material.dart' hide Paint;
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../data/catalog_repository.dart';
import '../models/paint.dart';
import '../services/paint_matcher.dart';
import 'paint_widgets.dart';

/// The paint's card: identity on top, cross-brand equivalents underneath.
///
/// This is the row-tap destination — the gesture the old action sheet used
/// to occupy. The equivalents answer the question a painter actually brings
/// to it: "the recipe says Citadel, I own Vallejo — what do I use?", graded
/// rather than declared, because our colour data comes from published
/// charts, not a spectrophotometer.
Future<void> showPaintDetail(BuildContext context, Paint paint) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final theme = Theme.of(sheetContext);
      final catalog = sheetContext.read<CatalogRepository>();
      final matches = crossBrandMatches(catalog, paint);

      return SafeArea(
        // Scrollable because it must not gamble on the screen: three match
        // rows plus the header already overflow a landscape phone.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: PaintSwatch(paint: paint, size: 48),
              title: Text(paint.name, style: theme.textTheme.titleMedium),
              subtitle: Text(
                [
                  paint.brandName,
                  paint.range,
                  if (paint.code != null) paint.code!,
                ].join(' · '),
              ),
              trailing: StatusToggles(paint: paint),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.equivalentsTitle,
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.equivalentsNone,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final match in matches)
                PaintTile(
                  paint: match.paint,
                  trailing: _TierChip(tier: match.tier),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                l10n.equivalentsDisclaimer,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
          ),
        ),
      );
    },
  );
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final MatchTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, bg) = switch (tier) {
      MatchTier.twin => (l10n.equivalentsTierTwin, scheme.primaryContainer),
      MatchTier.close =>
        (l10n.equivalentsTierClose, scheme.secondaryContainer),
      MatchTier.approximate =>
        (l10n.equivalentsTierApprox, scheme.surfaceContainerHighest),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
