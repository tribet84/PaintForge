import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/action_batcher.dart';

void main() {
  test('a single record settles with count 1 and that value', () async {
    int? settledCount;
    String? settledLast;
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 30),
      onSettled: (count, last) {
        settledCount = count;
        settledLast = last;
      },
    );

    batcher.record('Abaddon Black');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(settledCount, 1);
    expect(settledLast, 'Abaddon Black');
  });

  test('rapid repeated records settle exactly once with the total count',
      () async {
    var settledTimes = 0;
    int? settledCount;
    String? settledLast;
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 40),
      onSettled: (count, last) {
        settledTimes++;
        settledCount = count;
        settledLast = last;
      },
    );

    // Ten rapid actions, each well inside the previous one's debounce window
    // — this is exactly the "tap bought-it ten times" scenario.
    for (var i = 0; i < 10; i++) {
      batcher.record('paint-$i');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(
      settledTimes,
      1,
      reason: 'ten rapid actions must produce ONE summary, not a queue of ten',
    );
    expect(settledCount, 10);
    expect(settledLast, 'paint-9');
  });

  test('two separate bursts, spaced apart, settle as two batches', () async {
    final counts = <int>[];
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 30),
      onSettled: (count, last) => counts.add(count),
    );

    batcher.record('a');
    batcher.record('b');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    batcher.record('c');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(counts, [2, 1]);
  });

  test('discard drops a pending batch without ever calling onSettled',
      () async {
    var called = false;
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 30),
      onSettled: (count, last) => called = true,
    );

    batcher.record('a');
    batcher.discard();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(called, isFalse);
  });

  test('a record after discard starts a fresh batch, not a continuation',
      () async {
    int? settledCount;
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 30),
      onSettled: (count, last) => settledCount = count,
    );

    batcher.record('a');
    batcher.record('b');
    batcher.discard();

    batcher.record('c');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      settledCount,
      1,
      reason: 'the discarded a/b must not leak into the next batch\'s count',
    );
  });

  test('dispose cancels the pending timer', () async {
    var called = false;
    final batcher = ActionBatcher<String>(
      debounce: const Duration(milliseconds: 30),
      onSettled: (count, last) => called = true,
    );

    batcher.record('a');
    batcher.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(called, isFalse);
  });
}
