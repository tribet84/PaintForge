import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/services/sample_recipe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  for (final language in ['en', 'es']) {
    group('sample recipe ($language)', () {
      test('every paint exists in the bundled catalog', () {
        final sample = buildSampleRecipe(language);

        for (final paintId in sample.allPaintIds) {
          expect(
            catalog.byId(paintId),
            isNotNull,
            reason: '$paintId is referenced by the sample recipe but missing '
                'from the catalog — the example would render broken',
          );
        }
        expect(sample.allPaintIds, isNotEmpty);
      });

      test('teaches the core concepts: sections, ordered steps and links', () {
        final sample = buildSampleRecipe(language);

        expect(sample.sections.length, greaterThanOrEqualTo(3));
        expect(
          sample.sections.every((s) => s.steps.isNotEmpty),
          isTrue,
          reason: 'every section must demonstrate steps',
        );
        expect(sample.links, isNotEmpty);
        expect(sample.description, isNotEmpty);
        expect(sample.isPublished, isFalse);
      });
    });
  }

  test('sample recipe is localized', () {
    expect(buildSampleRecipe('es').name, isNot(buildSampleRecipe('en').name));
  });
}
