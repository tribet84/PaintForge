import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/state/inventory_provider.dart';

import 'fakes.dart';

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
