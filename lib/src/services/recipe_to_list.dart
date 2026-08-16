import '../models/recipe.dart';

/// Turns a recipe into the paint list it implies.
///
/// Paints keep the order they appear in the recipe (section by section, step
/// by step) rather than being alphabetised, so the resulting list reads in
/// painting order. Duplicates across sections collapse into one entry.
List<String> paintIdsForListFrom(Recipe recipe) {
  final seen = <String>{};
  final ordered = <String>[];
  for (final section in recipe.sections) {
    for (final paintId in section.paintIds) {
      if (seen.add(paintId)) ordered.add(paintId);
    }
  }
  return ordered;
}

/// Default name for a list generated from [recipe].
///
/// Falls back to the plain recipe name; the user can rename the list
/// afterwards like any other.
String listNameForRecipe(Recipe recipe) => recipe.name.trim();
