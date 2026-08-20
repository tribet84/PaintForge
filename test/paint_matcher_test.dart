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

  group('shelfSubstitutes', () {
    test('only ever offers pots the user actually owns', () {
      final target = catalog.byId('citadel-mephiston-red')!;
      final owned = {'tap-wp3118-pure-red', 'vallejo-72011-gory-red'};

      for (final m in shelfSubstitutes(catalog, owned, target)) {
        expect(owned, contains(m.paint.id));
      }
    });

    test('the same brand is welcome — a substitute you own beats a purchase',
        () {
      // Owning Citadel's Evil Sunz Scarlet while looking at Citadel's
      // Wild Rider Red: same brand, and exactly the answer wanted.
      final target = catalog.byId('citadel-wild-rider-red')!;
      final owned = {'citadel-evil-sunz-scarlet'};

      final subs = shelfSubstitutes(catalog, owned, target);
      expect(subs.map((m) => m.paint.id), contains('citadel-evil-sunz-scarlet'));
    });

    test('never offers the paint as a substitute for itself', () {
      final target = catalog.byId('citadel-abaddon-black')!;
      final owned = {'citadel-abaddon-black', 'vallejo-70950-black'};

      final subs = shelfSubstitutes(catalog, owned, target);
      expect(subs.map((m) => m.paint.id),
          isNot(contains('citadel-abaddon-black')));
    });

    test('an empty shelf yields no substitutes, not an error', () {
      final target = catalog.byId('citadel-mephiston-red')!;
      expect(shelfSubstitutes(catalog, const {}, target), isEmpty);
    });

    test('finish families still hold: an owned gold cannot stand in for a red',
        () {
      final target = catalog.byId('citadel-mephiston-red')!;
      final owned = {'tap-wp3189-bright-gold'};
      expect(shelfSubstitutes(catalog, owned, target), isEmpty);
    });
  });
}
