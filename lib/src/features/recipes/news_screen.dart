import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/published_recipe_repository.dart';
import '../../state/follows_provider.dart';
import '../../state/inventory_provider.dart';
import '../../widgets/paint_widgets.dart';
import '../../widgets/recipe_card.dart';
import 'public_recipe_screen.dart';

/// What the painters you follow published since you last looked.
///
/// The list is captured ONCE on open and the watermark advances right then:
/// clearing the bell must never yank the news out from under the reader.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final List<PublishedRecipe> _news;

  @override
  void initState() {
    super.initState();
    final follows = context.read<FollowsProvider>();
    _news = List.of(follows.news);
    // Seen means seen: the badge clears now, the list stays readable.
    follows.markAllSeen();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsTitle)),
      body: _news.isEmpty
          ? EmptyState(
              icon: Icons.notifications_none,
              title: l10n.newsTitle,
              body: l10n.newsEmpty,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                for (final published in _news)
                  RecipeCard(
                    recipe: published.recipe,
                    origin: RecipeOrigin.linked,
                    authorName: published.authorName,
                    // Same rule as everywhere else: no readiness verdict
                    // against an empty shelf.
                    readiness: inventory.entries.isEmpty
                        ? null
                        : published.recipe.readiness(inventory.entries),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PublicRecipeScreen(publishedId: published.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
