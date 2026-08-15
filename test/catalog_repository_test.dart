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
    expect(results, hasLength(1));
    expect(results.single.name, 'Abaddon Black');
    expect(results.single.brand, PaintBrand.citadel);
  });

  test('search finds Vallejo paints by code', () {
    final results = repository.search('70.950');
    expect(results, hasLength(1));
    expect(results.single.name, 'Black');
    expect(results.single.brand, PaintBrand.vallejo);
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
    expect(paint.color.toARGB32(), 0xFF9A1115);
  });
}
