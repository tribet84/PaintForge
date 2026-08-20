import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/services/paint_matcher.dart';

/// Run against the REAL catalogue: the feature's promise is that known
/// community equivalences fall out of the numbers, so the numbers are what
/// the tests read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository catalog;

  setUpAll(() async {
    catalog = await CatalogRepository.loadFromAssets();
  });

  test('finds the obvious cross-brand twin', () {
    // Vallejo's Model Color Black against Citadel's Abaddon Black: if the
    // algorithm cannot pair two near-blacks across brands, it is wrong.
    // (Sharper "famous" pairs like Pure Red ~ Mephiston Red measure worse
    // here than in hand-made charts — each brand's hex comes from a
    // different published source, and sources carry systematic offsets.
    // That is a data ceiling, not an algorithm bug, and it is why the UI
    // grades matches instead of declaring them.)
    final black = catalog.byId('vallejo-70950-black')!;
    final matches = crossBrandMatches(catalog, black, limit: 5);

    expect(
      matches.map((m) => m.paint.name),
      contains('Abaddon Black'),
    );
  });

  test('never offers a paint from the same brand', () {
    final paint = catalog.byId('citadel-mephiston-red')!;
    for (final m in crossBrandMatches(catalog, paint, limit: 10)) {
      expect(m.paint.brand, isNot(paint.brand));
    }
  });

  test('a metallic is never matched with a matte paint', () {
    // A gold and a brown can share a hex and share nothing on a mini.
    final gold = catalog.byId('tap-wp3189-bright-gold')!;
    for (final m in crossBrandMatches(catalog, gold, limit: 10)) {
      expect(m.paint.range.toLowerCase(), contains('metallic'),
          reason: '${m.paint.name} (${m.paint.range}) is not a metallic');
    }
  });

  test('a wash is matched against translucent ranges only', () {
    final wash = catalog.byId('tap-wp3199-dark-tone')!;
    const translucent = [
      'contrast', 'shade', 'speedpaint', 'xpress', 'wash', 'ink', 'quickshade',
    ];
    for (final m in crossBrandMatches(catalog, wash, limit: 10)) {
      expect(
        translucent.any((t) => m.paint.range.toLowerCase().contains(t)),
        isTrue,
        reason: '${m.paint.name} (${m.paint.range}) is opaque',
      );
    }
  });

  test('matches come back best-first with honest tiers', () {
    final paint = catalog.byId('citadel-abaddon-black')!;
    final matches = crossBrandMatches(catalog, paint);

    expect(matches, isNotEmpty);
    for (var i = 1; i < matches.length; i++) {
      expect(matches[i].deltaE, greaterThanOrEqualTo(matches[i - 1].deltaE));
    }
    for (final m in matches) {
      expect(m.deltaE, lessThan(10));
    }
  });

  test('a paint with no recorded colour offers no matches', () {
    final unknown = catalog.paints.where((p) => p.color == null);
    for (final p in unknown) {
      expect(crossBrandMatches(catalog, p), isEmpty,
          reason: 'guessing matches for ${p.name} would be invention');
    }
  });
}
