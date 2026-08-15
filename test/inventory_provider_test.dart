import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/inventory_repository.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';

/// In-memory repository so provider logic can be tested without Firestore.
class FakeInventoryRepository implements InventoryRepository {
  final _entries = <String, InventoryEntry>{};
  final _controller =
      StreamController<Map<String, InventoryEntry>>.broadcast();

  void _emit() => _controller.add(Map.of(_entries));

  @override
  Stream<Map<String, InventoryEntry>> watchEntries() {
    // Subscribe to the broadcast stream synchronously so no update emitted
    // right after construction is ever missed, and replay the current state
    // to the new listener.
    final controller = StreamController<Map<String, InventoryEntry>>();
    controller.add(Map.of(_entries));
    final subscription = _controller.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
    return controller.stream;
  }

  @override
  Future<void> setStatus(String paintId, PaintStatus status) async {
    _entries[paintId] = InventoryEntry(paintId: paintId, status: status);
    _emit();
  }

  @override
  Future<void> remove(String paintId) async {
    _entries.remove(paintId);
    _emit();
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeInventoryRepository repository;
  late InventoryProvider provider;

  setUp(() {
    repository = FakeInventoryRepository();
    provider = InventoryProvider(repository: repository);
  });

  tearDown(() => provider.dispose());

  test('starts empty once loaded', () async {
    await pump();
    expect(provider.loaded, isTrue);
    expect(provider.owned, isEmpty);
    expect(provider.shoppingList, isEmpty);
  });

  test('in-stock and low paints are owned; low ones need buying', () async {
    await provider.setStatus('paint-a', PaintStatus.inStock);
    await provider.setStatus('paint-b', PaintStatus.low);
    await pump();

    expect(provider.owned.map((e) => e.paintId), containsAll(['paint-a', 'paint-b']));
    expect(provider.statusOf('paint-a'), PaintStatus.inStock);
    expect(provider.runningLow.single.paintId, 'paint-b');
    expect(provider.shoppingList.single.paintId, 'paint-b');
  });

  test('wishlist paints are on the shopping list but not owned', () async {
    await provider.setStatus('paint-c', PaintStatus.wishlist);
    await pump();

    expect(provider.owned, isEmpty);
    expect(provider.wishlist.single.paintId, 'paint-c');
    expect(provider.shoppingList.single.paintId, 'paint-c');
  });

  test('marking a paint as purchased moves it to in stock', () async {
    await provider.setStatus('paint-d', PaintStatus.low);
    await provider.markPurchased('paint-d');
    await pump();

    expect(provider.statusOf('paint-d'), PaintStatus.inStock);
    expect(provider.shoppingList, isEmpty);
    expect(provider.owned.single.paintId, 'paint-d');
  });

  test('removing a paint clears it completely', () async {
    await provider.setStatus('paint-e', PaintStatus.inStock);
    await provider.remove('paint-e');
    await pump();

    expect(provider.statusOf('paint-e'), isNull);
    expect(provider.owned, isEmpty);
  });
}
