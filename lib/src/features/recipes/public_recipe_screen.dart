import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../data/published_recipe_repository.dart';
import '../../models/inventory_entry.dart';
import '../../models/recipe.dart';
import '../../services/external_link.dart';
import '../../state/inventory_provider.dart';
import '../../state/recipes_provider.dart';
import '../../widgets/paint_list_widgets.dart';
import '../../widgets/paint_widgets.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/recipe_section_card.dart';
import 'recipe_actions.dart';

/// A recipe shared by another painter, opened from a link or from the
/// "linked recipes" section.
///
/// Rendered straight from the live public document: when the author updates
/// the recipe, this screen shows the latest version — that is the point of
/// linking instead of cloning.
class PublicRecipeScreen extends StatefulWidget {
  const PublicRecipeScreen({
    super.key,
    required this.publishedId,
    this.fromSharedLink = false,
  });

  final String publishedId;

  /// True when the app was opened through someone's share link. The screen
  /// then offers to save the recipe straight away, which is what the link
  /// was for — rather than making the visitor hunt for the button.
  final bool fromSharedLink;

  @override
  State<PublicRecipeScreen> createState() => _PublicRecipeScreenState();
}

class _PublicRecipeScreenState extends State<PublicRecipeScreen> {
  late final PublishedRecipeRepository _repository;
  late final Stream<PublishedRecipe?> _stream;
  int? _linkCount;
  bool _invitationShown = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<PublishedRecipeRepository>();
    _stream = _repository.watchPublished(widget.publishedId);
    _refreshLinkCount();
  }

  Future<void> _refreshLinkCount() async {
    final count = await _repository.linkCount(widget.publishedId);
    if (mounted) setState(() => _linkCount = count);
  }

  /// Shown at most once, and only after the recipe resolved — offering to
  /// save a recipe that turned out to be unshared would be nonsense.
  Future<void> _offerToLink(PublishedRecipe published) async {
    if (_invitationShown) return;
    _invitationShown = true;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipes = context.read<RecipesProvider>();

    if (recipes.isLinked(published.id)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recipeAlreadyLinked)),
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.recipeInvitationTitle),
        content: Text(
          l10n.recipeInvitationBody(
            published.recipe.name,
            published.authorName.isEmpty ? '—' : published.authorName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.recipeInvitationJustLook),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.recipeInvitationLink),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    await recipes.link(published.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.recipeLinked)));
    await _refreshLinkCount();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = context.read<CatalogRepository>();
    final inventory = context.watch<InventoryProvider>();
    final recipes = context.watch<RecipesProvider>();

    return StreamBuilder<PublishedRecipe?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final published = snapshot.data;
        if (published == null) {
          final isLinked = recipes.isLinked(widget.publishedId);
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.link_off,
              title: l10n.recipeNotShared,
              body: l10n.recipeNotSharedBody,
              // Otherwise a dead link stays in the user's recipe list
              // forever, with no way to clear it.
              action: isLinked
                  ? OutlinedButton.icon(
                      onPressed: () => _removeDeadLink(context),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.recipeUnlinkAction),
                    )
                  : null,
            ),
          );
        }

        if (widget.fromSharedLink) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _offerToLink(published);
          });
        }

        final recipe = published.recipe;
        final readiness = recipe.readiness(inventory.entries);
        final linked = recipes.isLinked(published.id);
        final dateFormat = DateFormat.yMMMd(
          Localizations.localeOf(context).toLanguageTag(),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(recipe.name),
            actions: [
              IconButton(
                tooltip: l10n.recipeCreateList,
                icon: const Icon(Icons.playlist_add),
                onPressed: () => createListFromRecipe(context, recipe),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              // The link/unlink button is always there; the shopping button
              // is added on top of it when needed, so the clearance grows.
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                readiness.needsShopping ? 160 : 96,
              ),
              children: [
                if (recipe.hasPhoto) ...[
                  RecipePhoto(
                    recipe: recipe,
                    height: 200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 16),
                ],
                // Author + freshness: the reason linking beats cloning.
                Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.recipeByAuthor(
                          published.authorName.isEmpty
                              ? '—'
                              : published.authorName,
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      l10n.recipeUpdatedOn(
                        dateFormat.format(recipe.updatedAt),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (_linkCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.recipeLinkedCount(_linkCount!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                if (recipe.description.isNotEmpty) ...[
                  Text(recipe.description),
                  const SizedBox(height: 16),
                ],
                if (recipe.allPaintIds.isNotEmpty) ...[
                  Row(
                    children: [
                      PaintListStatusChip(readiness: readiness),
                      const Spacer(),
                      Text(
                        l10n.listPaintCount(readiness.total),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PaintListReadinessBar(readiness: readiness),
                  const SizedBox(height: 16),
                ],
                if (recipe.links.isNotEmpty) ...[
                  Text(
                    l10n.recipeLinksTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  for (final link in recipe.links)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        link.isYouTube ? Icons.ondemand_video : Icons.link,
                      ),
                      title: Text(link.title),
                      subtitle: Text(
                        link.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => openExternalLink(link.url),
                    ),
                  const SizedBox(height: 8),
                ],
                for (final section in recipe.sections)
                  RecipeSectionCard(section: section, catalog: catalog),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (readiness.needsShopping)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.extended(
                    heroTag: 'public-to-shopping',
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                    onPressed: () => _addMissingToShopping(context, recipe),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(l10n.listAddMissingToShopping),
                  ),
                ),
              FloatingActionButton.extended(
                heroTag: 'public-link',
                onPressed: () => _toggleLink(context, linked),
                icon: Icon(linked ? Icons.link_off : Icons.link),
                label: Text(
                  linked ? l10n.recipeUnlinkAction : l10n.recipeLinkAction,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeDeadLink(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipes = context.read<RecipesProvider>();

    await recipes.unlink(widget.publishedId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.recipeUnlinked)));
    navigator.pop();
  }

  Future<void> _toggleLink(BuildContext context, bool linked) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipes = context.read<RecipesProvider>();

    if (linked) {
      await recipes.unlink(widget.publishedId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.recipeUnlinked)));
    } else {
      await recipes.link(widget.publishedId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.recipeLinked)));
    }
    await _refreshLinkCount();
  }

  Future<void> _addMissingToShopping(
    BuildContext context,
    Recipe recipe,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();

    // Only paints with no entry at all need adding; the rest are already
    // low or wishlisted, so they are on the list already.
    final missing = recipe.allPaintIds
        .where((paintId) => inventory.statusOf(paintId) == null)
        .toList();
    await inventory.setStatusForAll(missing, PaintStatus.wishlist);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.listAddedToShopping(missing.length))),
    );
  }
}
