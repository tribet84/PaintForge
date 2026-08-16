import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/paint_list.dart';
import '../models/recipe.dart';
import '../services/image_compressor.dart';
import 'paint_list_widgets.dart';

/// How this recipe relates to the signed-in user, which is the only thing
/// that differs between a recipe you wrote and one you linked.
enum RecipeOrigin {
  /// Yours, kept to yourself.
  ownPrivate,

  /// Yours, published for others.
  ownShared,

  /// Someone else's, linked into your account.
  linked,
}

/// One recipe row.
///
/// Deliberately the SAME widget for your own recipes and the ones you linked:
/// they are the same kind of thing to read, and only the badge changes. Two
/// separate card widgets had already drifted into two different layouts.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.origin,
    required this.onTap,
    this.readiness,
    this.authorName,
  });

  final Recipe recipe;
  final RecipeOrigin origin;
  final VoidCallback onTap;

  /// Null while a linked recipe is still loading from the public collection.
  final PaintListReadiness? readiness;

  /// Shown for linked recipes so the author stays visible.
  final String? authorName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photo = decodePhoto(recipe.photo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  // A corrupt stored photo must not take the card with it.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      _OriginBadge(origin: origin),
                      if (readiness != null &&
                          recipe.allPaintIds.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        PaintListStatusChip(readiness: readiness!),
                      ],
                    ],
                  ),
                  if (authorName != null && authorName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.recipeByAuthor(authorName!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.recipeSectionsCount(recipe.sections.length)} · '
                    '${l10n.listPaintCount(recipe.allPaintIds.length)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one thing that differs per origin: shared, private, or linked.
class _OriginBadge extends StatelessWidget {
  const _OriginBadge({required this.origin});

  final RecipeOrigin origin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (origin) {
      RecipeOrigin.ownShared => (Icons.public, l10n.recipeSharedBadge, scheme.primary),
      RecipeOrigin.ownPrivate => (Icons.lock_outline, l10n.recipePrivate, scheme.outline),
      RecipeOrigin.linked => (Icons.link, l10n.recipeLinkedBadge, scheme.tertiary),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
