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
    'assets/catalog/ak.json',
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
      final brandPaints = <Paint>[
        for (final entry in data['paints'] as List<dynamic>)
          Paint.fromJson(
            entry as Map<String, dynamic>,
            brand: brand,
            brandName: brandName,
          ),
      ];
      // Ranges come in the catalogue's curated order, not alphabetical:
      // sorted by name, Citadel opened on "Air" and a newcomer's first
      // screen was forty-six airbrush paints. The workhorse ranges go
      // first; a range the file forgot to place sorts after the curated
      // ones rather than breaking the load.
      final order = (data['rangeOrder'] as List<dynamic>? ?? const [])
          .cast<String>();
      final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
      brandPaints.sort((a, b) {
        final byRange = (rank[a.range] ?? order.length)
            .compareTo(rank[b.range] ?? order.length);
        if (byRange != 0) return byRange;
        if (a.range != b.range) return a.range.compareTo(b.range);
        return a.name.compareTo(b.name);
      });
      paints.addAll(brandPaints);
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
