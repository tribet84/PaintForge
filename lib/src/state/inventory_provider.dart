import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/inventory_repository.dart';
import '../models/inventory_entry.dart';

/// Holds the live inventory for the signed-in user.
class InventoryProvider extends ChangeNotifier {
  InventoryProvider({required InventoryRepository repository})
      : _repository = repository {
    _subscription = _repository.watchEntries().listen((entries) {
      _entries = entries;
      _loaded = true;
      notifyListeners();
    });
  }

  final InventoryRepository _repository;
  StreamSubscription<Map<String, InventoryEntry>>? _subscription;

  Map<String, InventoryEntry> _entries = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Map<String, InventoryEntry> get entries => _entries;

  PaintStatus? statusOf(String paintId) => _entries[paintId]?.status;

  /// Paints the user physically owns (in stock or running low).
  List<InventoryEntry> get owned =>
      _entries.values.where((e) => e.owned).toList();

  /// Entries that belong on the shopping list.
  List<InventoryEntry> get shoppingList =>
      _entries.values.where((e) => e.needsBuying).toList();

  List<InventoryEntry> get runningLow =>
      _entries.values.where((e) => e.status == PaintStatus.low).toList();

  List<InventoryEntry> get wishlist =>
      _entries.values.where((e) => e.status == PaintStatus.wishlist).toList();

  Future<void> setStatus(String paintId, PaintStatus status) =>
      _repository.setStatus(paintId, status);

  Future<void> remove(String paintId) => _repository.remove(paintId);

  /// Bulk equivalents — one round trip instead of one per paint.
  Future<void> setStatusForAll(
    Iterable<String> paintIds,
    PaintStatus status,
  ) =>
      _repository.setStatusForAll(paintIds, status);

  Future<void> removeAll(Iterable<String> paintIds) =>
      _repository.removeAll(paintIds);

  /// Every purchased paint goes (back) to the shelf as in stock, in one write.
  Future<void> markAllPurchased(Iterable<String> paintIds) =>
      _repository.setStatusForAll(paintIds, PaintStatus.inStock);

  /// A purchased paint goes (back) to the shelf as in stock.
  Future<void> markPurchased(String paintId) =>
      setStatus(paintId, PaintStatus.inStock);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
