import 'package:flutter/material.dart' hide Paint;

import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../data/catalog_repository.dart';
import '../models/inventory_entry.dart';
import '../models/paint.dart';
import '../models/recipe.dart';
import '../services/paint_matcher.dart';
import '../state/inventory_provider.dart';
import 'paint_detail_sheet.dart';
import 'paint_widgets.dart';
import 'technique_widgets.dart';

/// Read-only rendering of one recipe section: techniques, the ordered steps
/// and the closing notes. Shared by the owner's detail view and the public
/// recipe view so a shared recipe always looks the same everywhere.
class RecipeSectionCard extends StatelessWidget {
  const RecipeSectionCard({
    super.key,
    required this.section,
    required this.catalog,
  });

  final RecipeSection section;
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.name, style: theme.textTheme.titleMedium),
            if (section.techniques.isNotEmpty) ...[
              const SizedBox(height: 8),
              TechniqueChips(techniques: section.techniques),
            ],
            const SizedBox(height: 8),
            if (section.steps.isEmpty)
              Text(
                l10n.recipeEmptySection,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var i = 0; i < section.steps.length; i++)
                _StepRow(
                  index: i + 1,
                  step: section.steps[i],
                  catalog: catalog,
                  paint: section.steps[i].paintId == null
                      ? null
                      : catalog.byId(section.steps[i].paintId!),
                ),
            if (section.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(section.notes, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.catalog,
    this.paint,
  });

  final int index;
  final RecipeStep step;
  final CatalogRepository catalog;
  final Paint? paint;

  /// The best substitute the reader already owns, or null when the step's
  /// paint is on their shelf (nothing to substitute), unknown, or nothing
  /// they own comes honestly close.
  ///
  /// This is where the recipe feature and the colour matching earn their
  /// keep together: the most expensive moment of following someone else's
  /// recipe is the shopping list it implies. Each step answers with the
  /// pot the reader already has before implying a purchase.
  PaintMatch? _shelfSubstitute(BuildContext context) {
    final target = paint;
    if (target == null) return null;
    final inventory = context.watch<InventoryProvider?>();
    if (inventory == null) return null;
    final ownedIds = {
      for (final e in inventory.entries.values)
        if (e.status == PaintStatus.inStock || e.status == PaintStatus.low)
          e.paintId,
    };
    if (ownedIds.contains(target.id)) return null;
    final subs = shelfSubstitutes(catalog, ownedIds, target, limit: 1);
    return subs.isEmpty ? null : subs.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final substitute = _shelfSubstitute(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (paint != null) ...[
            PaintSwatch(paint: paint!, size: 24),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (step.title.isNotEmpty)
                        TextSpan(
                          text: paint == null ? step.title : '${step.title}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (paint != null) TextSpan(text: paint!.name),
                    ],
                  ),
                ),
                if (step.note.isNotEmpty)
                  Text(
                    step.note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (substitute != null)
                  InkWell(
                    onTap: () => showPaintDetail(context, substitute.paint),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz,
                              size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${l10n.shelfSubstitutesTitle}: '
                              '${substitute.paint.name} · '
                              '${switch (substitute.tier) {
                                MatchTier.twin => l10n.equivalentsTierTwin,
                                MatchTier.close => l10n.equivalentsTierClose,
                                MatchTier.approximate =>
                                  l10n.equivalentsTierApprox,
                              }}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
