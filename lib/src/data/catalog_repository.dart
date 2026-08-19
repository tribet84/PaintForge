import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/paint.dart';

/// Loads and queries the bundled paint catalog (JSON assets, one per brand).
class CatalogRepository {
  CatalogRepository._(this.paints) : _byId = {for (final p in paints) p.id: p};

  static const assetPaths = [
    'assets/catalog/citadel.json',
    'assets/catalog/vallejo.json',
    'assets/catalog/army_painter.json',
    'assets/catalog/green_stuff_world.json',
  ];

  final List<Paint> paints;
  final Map<String, Paint> _byId;

  static Future<CatalogRepository> loadFromAssets({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final paints = <Paint>[];
    for (final path in assetPaths) {
      final raw = await assetBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final brand = PaintBrand.fromId(data['brand'] as String);
      final brandName = data['brandName'] as String;
      for (final entry in data['paints'] as List<dynamic>) {
        paints.add(
          Paint.fromJson(
            entry as Map<String, dynamic>,
            brand: brand,
            brandName: brandName,
          ),
        );
      }
    }
    return CatalogRepository._(List.unmodifiable(paints));
  }

  Paint? byId(String id) => _byId[id];

  /// Free-text search, optionally restricted to a single brand and, within
  /// it, to a single range (e.g. Vallejo "Model Wash"). Range names only make
  /// sense per brand — several brands have a "Washes"-like range — so [range]
  /// is meaningless without [brand].
  List<Paint> search(String query, {PaintBrand? brand, String? range}) {
    return paints
        .where((p) =>
            (brand == null || p.brand == brand) &&
            (range == null || p.range == range) &&
            p.matches(query))
        .toList();
  }
}
