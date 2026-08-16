import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/services/recipe_to_list.dart';

Recipe recipeWith(List<RecipeSection> sections, {String name = 'Necron Lord'}) =>
    Recipe(
      id: 'r1',
      name: name,
      sections: sections,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('paintIdsForListFrom', () {
    test('collects paints across every section', () {
      final recipe = recipeWith(const [
        RecipeSection(
          name: 'Armour',
          steps: [
            RecipeStep(title: 'Base', paintId: 'a'),
            RecipeStep(title: 'Wash', paintId: 'b'),
          ],
        ),
        RecipeSection(
          name: 'Gems',
          steps: [RecipeStep(title: 'Base', paintId: 'c')],
        ),
      ]);

      expect(paintIdsForListFrom(recipe), ['a', 'b', 'c']);
    });

    test('keeps painting order rather than alphabetising', () {
      final recipe = recipeWith(const [
        RecipeSection(
          name: 'Armour',
          steps: [
            RecipeStep(title: 'Base', paintId: 'zinc'),
            RecipeStep(title: 'Highlight', paintId: 'alpha'),
          ],
        ),
      ]);

      expect(
        paintIdsForListFrom(recipe),
        ['zinc', 'alpha'],
        reason: 'the recipe order is the useful order',
      );
    });

    test('a paint reused across sections appears once', () {
      final recipe = recipeWith(const [
        RecipeSection(
          name: 'Armour',
          steps: [RecipeStep(title: 'Base', paintId: 'shared')],
        ),
        RecipeSection(
          name: 'Base',
          steps: [
            RecipeStep(title: 'Base', paintId: 'shared'),
            RecipeStep(title: 'Wash', paintId: 'other'),
          ],
        ),
      ]);

      expect(paintIdsForListFrom(recipe), ['shared', 'other']);
    });

    test('steps without a paint contribute nothing', () {
      final recipe = recipeWith(const [
        RecipeSection(
          name: 'Finish',
          steps: [
            RecipeStep(title: 'Varnish'),
            RecipeStep(title: 'Base', paintId: 'a'),
          ],
        ),
      ]);

      expect(paintIdsForListFrom(recipe), ['a']);
    });

    test('a recipe with no paints yields an empty list', () {
      expect(paintIdsForListFrom(recipeWith(const [])), isEmpty);
      expect(
        paintIdsForListFrom(
          recipeWith(const [RecipeSection(name: 'Empty')]),
        ),
        isEmpty,
      );
    });

    test('matches the recipe view of its own paints', () {
      final recipe = recipeWith(const [
        RecipeSection(
          name: 'A',
          steps: [
            RecipeStep(title: 'x', paintId: 'a'),
            RecipeStep(title: 'y', paintId: 'b'),
          ],
        ),
      ]);

      expect(paintIdsForListFrom(recipe).toSet(), recipe.allPaintIds);
    });
  });

  group('listNameForRecipe', () {
    test('uses the recipe name', () {
      expect(listNameForRecipe(recipeWith(const [])), 'Necron Lord');
    });

    test('trims stray whitespace so the list name is clean', () {
      expect(
        listNameForRecipe(recipeWith(const [], name: '  Ultramarines  ')),
        'Ultramarines',
      );
    });
  });
}
