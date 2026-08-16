import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../models/recipe.dart';
import '../../services/recipe_to_list.dart';
import '../../state/paint_lists_provider.dart';

/// Asks whether to turn [recipe] into a paint list, and does it.
///
/// The list is a snapshot of the paints the recipe uses: it does not stay in
/// sync with the recipe afterwards, which is deliberate — a list tracks what
/// you need on the shelf for a project, and editing one should never
/// silently rewrite the other.
Future<void> createListFromRecipe(BuildContext context, Recipe recipe) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final lists = context.read<PaintListsProvider>();

  final paintIds = paintIdsForListFrom(recipe);
  if (paintIds.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.recipeEmptySection)),
    );
    return;
  }

  final name = listNameForRecipe(recipe);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.recipeCreateList),
      content: Text(l10n.recipeCreateListBody(paintIds.length, name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.actionConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await lists.createWithPaints(name, paintIds);
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(l10n.recipeListCreated(name))));
}
