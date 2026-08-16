import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/paint_list.dart';
import '../models/recipe.dart';
import 'paint_list_widgets.dart';
import 'recipe_photo.dart';

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
///
/// A recipe with a photo renders as a gallery card — the photo fills the
/// card, a scrim keeps the overlaid text legible over any picture, and the
/// details that used to sit in a plain block below become chips over the
/// image. A recipe with no photo falls back to the plain block layout: there
/// is nothing to put a scrim over, and a colour placeholder would just be
/// decoration standing in for content that is not there.
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: recipe.hasPhoto ? _photoCard(context) : _plainCard(context),
      ),
    );
  }

  Widget _photoCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const height = 200.0;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RecipePhoto(recipe: recipe, height: height),
          // Transparent at the top so the photo itself still reads, opaque
          // at the bottom so white text sits on solid ground regardless of
          // what the photo looks like underneath.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.4, 1.0],
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _OriginBadge(origin: origin, onDark: true),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                ),
                if (authorName != null && authorName!.isNotEmpty)
                  Text(
                    l10n.recipeByAuthor(authorName!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (readiness != null && recipe.allPaintIds.isNotEmpty)
                      _ReadinessOverlayChip(readiness: readiness!),
                    _InfoOverlayChip(
                      icon: Icons.palette_outlined,
                      label: l10n.listPaintCount(recipe.allPaintIds.length),
                    ),
                    _InfoOverlayChip(
                      icon: Icons.layers_outlined,
                      label: l10n.recipeSectionsCount(recipe.sections.length),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(recipe.name, style: theme.textTheme.titleMedium),
              ),
              _OriginBadge(origin: origin, onDark: false),
              if (readiness != null && recipe.allPaintIds.isNotEmpty) ...[
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
    );
  }
}

/// The one thing that differs per origin: shared, private, or linked.
class _OriginBadge extends StatelessWidget {
  const _OriginBadge({required this.origin, required this.onDark});

  final RecipeOrigin origin;

  /// True when painted over a photo — the icon then needs its own solid
  /// backdrop, since the theme colours it otherwise uses are tuned for a
  /// plain surface and can vanish against an arbitrary picture.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, color) = switch (origin) {
      RecipeOrigin.ownShared => (Icons.public, l10n.recipeSharedBadge, scheme.primary),
      RecipeOrigin.ownPrivate => (Icons.lock_outline, l10n.recipePrivate, scheme.outline),
      RecipeOrigin.linked => (Icons.link, l10n.recipeLinkedBadge, scheme.tertiary),
    };

    if (!onDark) {
      return Tooltip(message: label, child: Icon(icon, size: 16, color: color));
    }
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

/// Readiness pill for the photo overlay: a solid backdrop rather than plain
/// coloured text, so the verdict stays legible whatever the photo looks like.
class _ReadinessOverlayChip extends StatelessWidget {
  const _ReadinessOverlayChip({required this.readiness});

  final PaintListReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final style = paintListStatusStyle(context, readiness.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Plain fact pill (paint count, section count) for the photo overlay.
class _InfoOverlayChip extends StatelessWidget {
  const _InfoOverlayChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
