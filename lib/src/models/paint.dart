import 'dart:ui';

/// Brands bundled in the local catalog.
enum PaintBrand {
  citadel,
  vallejo,
  armyPainter,
  greenStuffWorld;

  static PaintBrand fromId(String id) =>
      PaintBrand.values.firstWhere((b) => b.name == id);
}

/// A paint from the bundled catalog. Immutable reference data — the user's
/// inventory only stores the paint [id].
class Paint {
  const Paint({
    required this.id,
    required this.brand,
    required this.brandName,
    required this.name,
    required this.range,
    required this.color,
    this.code,
  });

  final String id;
  final PaintBrand brand;
  final String brandName;
  final String name;
  final String range;
  final String? code;
  final Color color;

  factory Paint.fromJson(
    Map<String, dynamic> json, {
    required PaintBrand brand,
    required String brandName,
  }) {
    return Paint(
      id: json['id'] as String,
      brand: brand,
      brandName: brandName,
      name: json['name'] as String,
      range: json['range'] as String,
      code: json['code'] as String?,
      color: _parseHex(json['hex'] as String),
    );
  }

  static Color _parseHex(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  /// Case-insensitive match against name, code, range and brand name.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false) ||
        range.toLowerCase().contains(q) ||
        brandName.toLowerCase().contains(q);
  }
}
