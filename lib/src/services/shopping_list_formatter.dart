import '../models/paint.dart';

/// Localized labels the formatter needs, injected so the formatting logic
/// stays pure Dart and can be unit-tested without a widget tree.
class ShoppingListLabels {
  const ShoppingListLabels({
    required this.title,
    required this.lowSection,
    required this.wishlistSection,
    required this.attribution,
  });

  final String title;
  final String lowSection;
  final String wishlistSection;

  /// Credit line appended when sharing, e.g. "Generated with PaintForge".
  final String attribution;
}

/// Renders the shopping list as plain text, grouped by section and then by
/// brand, so it can be pasted into a chat or a notes app and still read as a
/// real shopping list.
class ShoppingListFormatter {
  const ShoppingListFormatter(this.labels);

  final ShoppingListLabels labels;

  String format({
    required List<Paint> low,
    required List<Paint> wishlist,
    bool includeAttribution = false,
  }) {
    final buffer = StringBuffer()..writeln(labels.title);

    _writeSection(buffer, labels.lowSection, low);
    _writeSection(buffer, labels.wishlistSection, wishlist);

    if (includeAttribution) {
      buffer
        ..writeln()
        ..writeln(labels.attribution);
    }
    return buffer.toString().trimRight();
  }

  void _writeSection(StringBuffer buffer, String title, List<Paint> paints) {
    if (paints.isEmpty) return;
    buffer
      ..writeln()
      ..writeln('$title (${paints.length})');
    for (final entry in groupByBrand(paints).entries) {
      buffer.writeln('  ${entry.key}');
      for (final paint in entry.value) {
        buffer.writeln('    - ${describe(paint)}');
      }
    }
  }

  /// Brands in alphabetical order, paints alphabetical within each brand.
  static Map<String, List<Paint>> groupByBrand(List<Paint> paints) {
    final grouped = <String, List<Paint>>{};
    for (final paint in paints) {
      grouped.putIfAbsent(paint.brandName, () => []).add(paint);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  /// "Abaddon Black (Base · 21-25)" — range always, code only when present.
  static String describe(Paint paint) {
    final details = [paint.range, if (paint.code != null) paint.code!];
    return '${paint.name} (${details.join(' · ')})';
  }
}
