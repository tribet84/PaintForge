import 'package:flutter/material.dart' hide Paint;

import '../../l10n/generated/app_localizations.dart';
import '../data/catalog_repository.dart';
import '../models/paint.dart';
import '../models/recipe.dart';
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
  const _StepRow({required this.index, required this.step, this.paint});

  final int index;
  final RecipeStep step;
  final Paint? paint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
