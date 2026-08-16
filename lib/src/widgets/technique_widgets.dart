import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/recipe.dart';

/// Localized label for a painting technique.
String techniqueLabel(AppLocalizations l10n, PaintTechnique technique) {
  return switch (technique) {
    PaintTechnique.basecoat => l10n.techniqueBasecoat,
    PaintTechnique.layering => l10n.techniqueLayering,
    PaintTechnique.wash => l10n.techniqueWash,
    PaintTechnique.drybrush => l10n.techniqueDrybrush,
    PaintTechnique.highlight => l10n.techniqueHighlight,
    PaintTechnique.glaze => l10n.techniqueGlaze,
    PaintTechnique.stipple => l10n.techniqueStipple,
    PaintTechnique.blending => l10n.techniqueBlending,
    PaintTechnique.freehand => l10n.techniqueFreehand,
  };
}

/// Read-only chips for the techniques used in a recipe section.
class TechniqueChips extends StatelessWidget {
  const TechniqueChips({super.key, required this.techniques});

  final Set<PaintTechnique> techniques;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Stable order: as declared in the enum.
    final ordered =
        PaintTechnique.values.where(techniques.contains).toList();
    return Wrap(
      spacing: 6,
      runSpacing: -8,
      children: [
        for (final technique in ordered)
          Chip(
            label: Text(techniqueLabel(l10n, technique)),
            visualDensity: VisualDensity.compact,
            labelStyle: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}
