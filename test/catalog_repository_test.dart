import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/catalog_repository.dart';
import 'package:paintforge/src/models/paint.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogRepository repository;

  setUpAll(() async {
    repository = await CatalogRepository.loadFromAssets();
  });

  test('loads all four brands from assets', () {
    final brands = repository.paints.map((p) => p.brand).toSet();
    expect(brands, PaintBrand.values.toSet());
    expect(repository.paints.length, greaterThan(200));
  });

  test('paint ids are unique', () {
    final ids = repository.paints.map((p) => p.id).toSet();
    expect(ids.length, repository.paints.length);
  });

  test('search finds paints by name regardless of case', () {
    final results = repository.search('abaddon');
    // Base and Air both carry an Abaddon Black — the point here is the
    // case-insensitive match, not the exact count.
    expect(results, isNotEmpty);
    expect(results.every((p) => p.name == 'Abaddon Black'), isTrue);
    expect(results.every((p) => p.brand == PaintBrand.citadel), isTrue);
  });

  test('search finds Vallejo paints by code', () {
    final results = repository.search('70.950');
    expect(results, hasLength(1));
    expect(results.single.name, 'Black');
    expect(results.single.brand, PaintBrand.vallejo);
  });

  test('range filter narrows a brand to one of its ranges', () {
    final washes = repository.search(
      '',
      brand: PaintBrand.vallejo,
      range: 'Game Color Wash',
    );
    expect(washes, hasLength(8));
    expect(washes.every((p) => p.range == 'Game Color Wash'), isTrue);
  });

  test('brand filter restricts results', () {
    final results = repository.search('black', brand: PaintBrand.armyPainter);
    expect(results, isNotEmpty);
    expect(results.every((p) => p.brand == PaintBrand.armyPainter), isTrue);
  });

  test('empty query returns the whole brand catalog', () {
    final citadel = repository.search('', brand: PaintBrand.citadel);
    expect(citadel.length, greaterThan(50));
  });

  test('byId resolves a known paint with parsed color', () {
    final paint = repository.byId('citadel-mephiston-red');
    expect(paint, isNotNull);
    expect(paint!.name, 'Mephiston Red');
    expect(paint.color?.toARGB32(), 0xFF9A1115);
  });

  test('a paint whose colour nobody has recorded parses with a null colour',
      () {
    // The catalogue lists names we can verify from the manufacturer long
    // before anyone measures the pot. Those must load, and must not be given
    // an invented colour on the way in.
    final paint = Paint.fromJson(
      const {'id': 'x-1', 'name': 'Unknown', 'range': 'Test'},
      brand: PaintBrand.citadel,
      brandName: 'Citadel',
    );

    expect(paint.color, isNull);
  });
}
