import 'inventory_entry.dart';

/// A user-defined set of paints — typically the palette for one miniature,
/// unit or army.
class PaintList {
  const PaintList({
    required this.id,
    required this.name,
    required this.paintIds,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> paintIds;
  final DateTime updatedAt;

  PaintList copyWith({String? name, List<String>? paintIds}) {
    return PaintList(
      id: id,
      name: name ?? this.name,
      paintIds: paintIds ?? this.paintIds,
      updatedAt: updatedAt,
    );
  }

  /// Readiness of this list given the user's current inventory.
  PaintListReadiness readiness(Map<String, InventoryEntry> inventory) =>
      readinessOf(paintIds, inventory);
}

/// Readiness of any set of paints given the user's current inventory.
///
/// [inventory] is the full paintId -> entry map; paints with no entry count
/// as missing, which is what makes a brand-new list read as "not ready".
/// A wishlist paint also counts as missing: it is not physically on the shelf.
/// Shared by paint lists and recipes so both verdicts always agree.
PaintListReadiness readinessOf(
  Iterable<String> paintIds,
  Map<String, InventoryEntry> inventory,
) {
  var total = 0;
  var inStock = 0;
  var low = 0;
  var missing = 0;
  for (final paintId in paintIds) {
    total++;
    switch (inventory[paintId]?.status) {
      case PaintStatus.inStock:
        inStock++;
      case PaintStatus.low:
        low++;
      case PaintStatus.wishlist:
      case null:
        missing++;
    }
  }
  return PaintListReadiness(
    total: total,
    inStock: inStock,
    low: low,
    missing: missing,
  );
}

/// How ready a [PaintList] is to be painted right now.
enum PaintListStatus {
  /// No paints in the list yet.
  empty,

  /// Every paint is owned with enough left.
  ready,

  /// Everything is owned, but some pots are about to run out.
  runningLow,

  /// At least one paint is not on the shelf at all.
  incomplete,
}

/// Counts behind a [PaintListStatus], so the UI can explain the verdict.
class PaintListReadiness {
  const PaintListReadiness({
    required this.total,
    required this.inStock,
    required this.low,
    required this.missing,
  });

  final int total;
  final int inStock;
  final int low;
  final int missing;

  /// Paints that need buying before this list can be painted comfortably:
  /// the missing ones plus the ones about to run out.
  int get needsBuying => low + missing;

  PaintListStatus get status {
    if (total == 0) return PaintListStatus.empty;
    if (missing > 0) return PaintListStatus.incomplete;
    if (low > 0) return PaintListStatus.runningLow;
    return PaintListStatus.ready;
  }

  /// Whether this list should nudge the user towards the shop.
  bool get needsShopping => needsBuying > 0;
}
