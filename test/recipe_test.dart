import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/paint_list.dart';
import 'package:paintforge/src/models/recipe.dart';

void main() {
  group('serialization', () {
    test('a section with steps survives a toMap/fromMap round trip', () {
      const section = RecipeSection(
        name: 'Armour',
        steps: [
          RecipeStep(
            title: 'Basecoat',
            paintId: 'citadel-leadbelcher',
            note: 'Generous drybrush',
          ),
          RecipeStep(title: 'Wash', paintId: 'citadel-agrax-earthshade'),
          RecipeStep(title: 'Varnish'),
        ],
        techniques: {PaintTechnique.basecoat, PaintTechnique.drybrush},
        notes: 'Two thin coats.',
      );

      final restored = RecipeSection.fromMap(section.toMap())!;

      expect(restored.name, section.name);
      expect(restored.steps.length, 3);
      expect(restored.steps[0].title, 'Basecoat');
      expect(restored.steps[0].paintId, 'citadel-leadbelcher');
      expect(restored.steps[0].note, 'Generous drybrush');
      expect(restored.steps[2].paintId, isNull);
      expect(restored.techniques, section.techniques);
      expect(restored.notes, section.notes);
    });

    test('steps keep their order — the order IS the recipe', () {
      const section = RecipeSection(
        name: 'Gem',
        steps: [
          RecipeStep(title: 'Base', paintId: 'a'),
          RecipeStep(title: 'Shade', paintId: 'b'),
          RecipeStep(title: 'Highlight', paintId: 'c'),
        ],
      );

      final restored = RecipeSection.fromMap(section.toMap())!;

      expect(
        restored.steps.map((s) => s.title).toList(),
        ['Base', 'Shade', 'Highlight'],
      );
    });

    test('legacy documents with a flat paintIds list are still readable', () {
      final restored = RecipeSection.fromMap({
        'name': 'Cloak',
        'paintIds': ['paint-a', 'paint-b'],
        'techniques': ['drybrush'],
        'notes': '',
      })!;

      expect(restored.steps.length, 2);
      expect(restored.paintIds, ['paint-a', 'paint-b']);
    });

    test('an unknown technique in stored data is skipped, not fatal', () {
      final restored = RecipeSection.fromMap({
        'name': 'Cloak',
        'steps': <Map<String, dynamic>>[],
        'techniques': ['drybrush', 'not-a-technique'],
        'notes': '',
      })!;

      expect(restored.techniques, {PaintTechnique.drybrush});
    });

    test('a link without url is dropped', () {
      expect(RecipeLink.fromMap({'title': 'Video'}), isNull);
    });

    test('detects YouTube links for the video icon', () {
      const video = RecipeLink(
        title: 'Tutorial',
        url: 'https://www.youtube.com/watch?v=abc',
      );
      const short = RecipeLink(title: 'Short', url: 'https://youtu.be/abc');
      const blog = RecipeLink(title: 'Blog', url: 'https://example.com/post');

      expect(video.isYouTube, isTrue);
      expect(short.isYouTube, isTrue);
      expect(blog.isYouTube, isFalse);
    });

    test('publishedId survives the round trip through toMap', () {
      final recipe = Recipe(
        id: 'r1',
        name: 'Test',
        publishedId: 'pub-1',
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(recipe.toMap()['publishedId'], 'pub-1');
      expect(recipe.isPublished, isTrue);
      expect(
        recipe.copyWith(clearPublishedId: true).isPublished,
        isFalse,
      );
    });
  });

  group('paints and readiness', () {
    Recipe recipe(List<RecipeSection> sections) => Recipe(
          id: 'r1',
          name: 'Ultramarines Captain',
          sections: sections,
          updatedAt: DateTime(2026, 1, 1),
        );

    test('section paintIds derive from steps, deduplicated in order', () {
      const section = RecipeSection(
        name: 'Armour',
        steps: [
          RecipeStep(title: 'Base', paintId: 'a'),
          RecipeStep(title: 'Wash', paintId: 'b'),
          RecipeStep(title: 'Highlight', paintId: 'a'),
          RecipeStep(title: 'Varnish'),
        ],
      );

      expect(section.paintIds, ['a', 'b']);
    });

    test('allPaintIds deduplicates across sections', () {
      final r = recipe(const [
        RecipeSection(
          name: 'Armour',
          steps: [
            RecipeStep(title: 'Base', paintId: 'a'),
            RecipeStep(title: 'Wash', paintId: 'b'),
          ],
        ),
        RecipeSection(
          name: 'Trim',
          steps: [
            RecipeStep(title: 'Base', paintId: 'b'),
            RecipeStep(title: 'Edge', paintId: 'c'),
          ],
        ),
      ]);

      expect(r.allPaintIds, {'a', 'b', 'c'});
    });

    test('readiness agrees with the shared readiness function', () {
      final r = recipe(const [
        RecipeSection(
          name: 'Armour',
          steps: [
            RecipeStep(title: 'Base', paintId: 'a'),
            RecipeStep(title: 'Wash', paintId: 'b'),
          ],
        ),
        RecipeSection(
          name: 'Trim',
          steps: [RecipeStep(title: 'Base', paintId: 'c')],
        ),
      ]);
      final inventory = {
        'a': const InventoryEntry(paintId: 'a', status: PaintStatus.inStock),
        'b': const InventoryEntry(paintId: 'b', status: PaintStatus.low),
      };

      final readiness = r.readiness(inventory);

      expect(readiness.total, 3);
      expect(readiness.inStock, 1);
      expect(readiness.low, 1);
      expect(readiness.missing, 1, reason: 'paint c has no entry');
      expect(readiness.status, PaintListStatus.incomplete);
    });
  });
}
