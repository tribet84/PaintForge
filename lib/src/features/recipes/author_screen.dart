import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/published_recipe_repository.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/brand_loader.dart';
import '../../widgets/recipe_card.dart';
import 'public_recipe_screen.dart';

/// Everything one author currently shares, newest first.
///
/// First rung of the social ladder, and deliberately the ONLY discovery
/// surface for now: you can only get here from a recipe somebody already
/// sent you, so a page with three recipes reads as a painter's shelf —
/// while a global browse with twelve would read as a dead app. The global
/// rung waits until there is enough content for it to advertise life
/// instead of absence.
class AuthorScreen extends StatefulWidget {
  const AuthorScreen({
    super.key,
    required this.ownerUid,
    required this.authorName,
  });

  final String ownerUid;
  final String authorName;

  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  late final Future<List<PublishedRecipe>> _recipes = context
      .read<PublishedRecipeRepository>()
      .byAuthor(widget.ownerUid);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authorRecipesTitle(widget.authorName))),
      body: FutureBuilder<List<PublishedRecipe>>(
        future: _recipes,
        builder: (context, snapshot) {
          final recipes = snapshot.data;
          if (recipes == null) {
            return const Center(child: BrandLoader());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  l10n.authorRecipesCount(recipes.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final published in recipes)
                RecipeCard(
                  recipe: published.recipe,
                  origin: RecipeOrigin.linked,
                  authorName: published.authorName,
                  readiness: published.recipe.readiness(inventory.entries),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PublicRecipeScreen(publishedId: published.id),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
