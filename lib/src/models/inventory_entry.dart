/// Status of a paint in the user's inventory.
///
/// Paints without an entry are simply "not owned". [low] and [wishlist]
/// entries make up the shopping list.
enum PaintStatus {
  /// Owned and with enough paint left.
  inStock,

  /// Owned but about to run out — shows up in the shopping list.
  low,

  /// Not owned but wanted — shows up in the shopping list.
  wishlist;

  static PaintStatus? tryParse(String? value) {
    if (value == null) return null;
    for (final status in PaintStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

/// A single inventory record, keyed by catalog paint id.
class InventoryEntry {
  const InventoryEntry({required this.paintId, required this.status});

  final String paintId;
  final PaintStatus status;

  /// Whether the user physically has this paint on the shelf.
  bool get owned => status == PaintStatus.inStock || status == PaintStatus.low;

  /// Whether this entry belongs on the shopping list.
  bool get needsBuying =>
      status == PaintStatus.low || status == PaintStatus.wishlist;
}
