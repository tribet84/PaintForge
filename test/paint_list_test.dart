import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/paint_list.dart';

PaintList listOf(List<String> paintIds) => PaintList(
      id: 'list-1',
      name: 'Ultramarines squad',
      paintIds: paintIds,
      updatedAt: DateTime(2026, 1, 1),
    );

Map<String, InventoryEntry> inventory(Map<String, PaintStatus> statuses) {
  return {
    for (final entry in statuses.entries)
      entry.key: InventoryEntry(paintId: entry.key, status: entry.value),
  };
}

void main() {
  test('an empty list reports the empty status', () {
    final readiness = listOf(const []).readiness(const {});

    expect(readiness.status, PaintListStatus.empty);
    expect(readiness.needsShopping, isFalse);
  });

  test('all paints in stock means ready to paint', () {
    final readiness = listOf(['a', 'b']).readiness(
      inventory({'a': PaintStatus.inStock, 'b': PaintStatus.inStock}),
    );

    expect(readiness.status, PaintListStatus.ready);
    expect(readiness.inStock, 2);
    expect(readiness.needsBuying, 0);
    expect(readiness.needsShopping, isFalse);
  });

  test('a running-low paint flags the whole list as running low', () {
    final readiness = listOf(['a', 'b']).readiness(
      inventory({'a': PaintStatus.inStock, 'b': PaintStatus.low}),
    );

    expect(readiness.status, PaintListStatus.runningLow);
    expect(readiness.low, 1);
    expect(readiness.needsBuying, 1);
    expect(readiness.needsShopping, isTrue);
  });

  test('a paint with no inventory entry counts as missing', () {
    final readiness = listOf(['a', 'b']).readiness(
      inventory({'a': PaintStatus.inStock}),
    );

    expect(readiness.missing, 1);
    expect(readiness.status, PaintListStatus.incomplete);
  });

  test('a wishlist paint is not on the shelf, so it counts as missing', () {
    final readiness = listOf(['a']).readiness(
      inventory({'a': PaintStatus.wishlist}),
    );

    expect(readiness.missing, 1);
    expect(readiness.inStock, 0);
    expect(readiness.status, PaintListStatus.incomplete);
  });

  test('missing outranks running low in the verdict', () {
    final readiness = listOf(['a', 'b', 'c']).readiness(
      inventory({'a': PaintStatus.inStock, 'b': PaintStatus.low}),
    );

    expect(readiness.low, 1);
    expect(readiness.missing, 1);
    expect(
      readiness.status,
      PaintListStatus.incomplete,
      reason: 'you cannot paint it at all if a paint is missing outright',
    );
    expect(readiness.needsBuying, 2);
  });

  test('counts always add up to the list size', () {
    final readiness = listOf(['a', 'b', 'c', 'd']).readiness(
      inventory({
        'a': PaintStatus.inStock,
        'b': PaintStatus.low,
        'c': PaintStatus.wishlist,
      }),
    );

    expect(
      readiness.inStock + readiness.low + readiness.missing,
      readiness.total,
    );
    expect(readiness.total, 4);
  });
}
