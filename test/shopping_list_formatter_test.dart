import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/paint.dart';
import 'package:paintforge/src/services/shopping_list_formatter.dart';

Paint paint(
  String name, {
  required PaintBrand brand,
  required String brandName,
  String range = 'Base',
  String? code,
}) {
  return Paint(
    id: name.toLowerCase().replaceAll(' ', '-'),
    brand: brand,
    brandName: brandName,
    name: name,
    range: range,
    code: code,
    color: const Color(0xFF000000),
  );
}

const labels = ShoppingListLabels(
  title: 'PintaMinis — Shopping list',
  lowSection: 'Running low',
  wishlistSection: 'Want to buy',
  attribution: 'Generated with PintaMinis · https://example.test',
);

void main() {
  const formatter = ShoppingListFormatter(labels);

  final abaddon = paint(
    'Abaddon Black',
    brand: PaintBrand.citadel,
    brandName: 'Citadel',
    code: '21-25',
  );
  final mephiston = paint(
    'Mephiston Red',
    brand: PaintBrand.citadel,
    brandName: 'Citadel',
  );
  final vallejoBlack = paint(
    'Black',
    brand: PaintBrand.vallejo,
    brandName: 'Vallejo',
    range: 'Model Color',
    code: '70.950',
  );

  test('groups paints by brand inside each section', () {
    final text = formatter.format(
      low: [mephiston, vallejoBlack, abaddon],
      wishlist: const [],
    );

    expect(text, contains('Running low (3)'));
    expect(text, contains('  Citadel'));
    expect(text, contains('  Vallejo'));
    // Citadel comes before Vallejo, and its paints are alphabetical.
    expect(
      text.indexOf('Abaddon Black'),
      lessThan(text.indexOf('Mephiston Red')),
    );
    expect(
      text.indexOf('Mephiston Red'),
      lessThan(text.indexOf('Vallejo')),
    );
  });

  test('keeps the two sections separate', () {
    final text = formatter.format(low: [abaddon], wishlist: [vallejoBlack]);

    expect(text, contains('Running low (1)'));
    expect(text, contains('Want to buy (1)'));
    expect(
      text.indexOf('Running low'),
      lessThan(text.indexOf('Want to buy')),
    );
  });

  test('omits an empty section entirely', () {
    final text = formatter.format(low: [abaddon], wishlist: const []);

    expect(text, contains('Running low'));
    expect(text, isNot(contains('Want to buy')));
  });

  test('includes the range and, when present, the code', () {
    final text = formatter.format(low: [abaddon, mephiston], wishlist: const []);

    expect(text, contains('Abaddon Black (Base · 21-25)'));
    expect(text, contains('Mephiston Red (Base)'));
  });

  test('attribution is opt-in', () {
    final without = formatter.format(low: [abaddon], wishlist: const []);
    final with_ = formatter.format(
      low: [abaddon],
      wishlist: const [],
      includeAttribution: true,
    );

    expect(without, isNot(contains('Generated with PintaMinis')));
    expect(with_, contains('Generated with PintaMinis'));
    expect(with_, endsWith('https://example.test'));
  });

  test('an empty list still carries the title', () {
    final text = formatter.format(low: const [], wishlist: const []);
    expect(text, 'PintaMinis — Shopping list');
  });

  test('groupByBrand sorts brands and paints alphabetically', () {
    final grouped = ShoppingListFormatter.groupByBrand([
      vallejoBlack,
      mephiston,
      abaddon,
    ]);

    expect(grouped.keys.toList(), ['Citadel', 'Vallejo']);
    expect(
      grouped['Citadel']!.map((p) => p.name).toList(),
      ['Abaddon Black', 'Mephiston Red'],
    );
  });
}
