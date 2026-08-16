import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/models/paint_list.dart';
import 'package:paintforge/src/widgets/paint_list_widgets.dart';

/// The readiness bar is the only at-a-glance signal on a list card, so it
/// has to actually paint. It previously rendered at zero height — the gap
/// was reserved but nothing was drawn — because a Row centres its children
/// by default and a childless ColoredBox given a loose height collapses.
/// Scoped to the bar itself: Material paints its own ColoredBoxes, so a bare
/// byType finder would measure the Scaffold background instead.
Finder _segments() => find.descendant(
      of: find.byType(PaintListReadinessBar),
      matching: find.byType(ColoredBox),
    );

void main() {
  Future<void> pumpBar(WidgetTester tester, PaintListReadiness readiness) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PaintListReadinessBar(readiness: readiness),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an all-in-stock bar paints a full-width segment',
      (tester) async {
    await pumpBar(
      tester,
      const PaintListReadiness(total: 2, inStock: 2, low: 0, missing: 0),
    );

    final segment = tester.getSize(_segments().first);
    expect(
      segment.height,
      greaterThan(0),
      reason: 'a zero-height bar is invisible to the user',
    );
    expect(segment.width, 300);
  });

  testWidgets('every segment of a mixed bar has height', (tester) async {
    await pumpBar(
      tester,
      const PaintListReadiness(total: 4, inStock: 2, low: 1, missing: 1),
    );

    final segments = _segments();
    expect(segments, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(
        tester.getSize(segments.at(i)).height,
        greaterThan(0),
        reason: 'segment $i must be visible',
      );
    }
  });

  testWidgets('segment widths are proportional to the counts', (tester) async {
    await pumpBar(
      tester,
      const PaintListReadiness(total: 4, inStock: 2, low: 1, missing: 1),
    );

    final segments = _segments();
    final inStock = tester.getSize(segments.at(0)).width;
    final low = tester.getSize(segments.at(1)).width;

    expect(inStock, closeTo(low * 2, 1));
  });

  testWidgets('an empty list draws no bar at all', (tester) async {
    await pumpBar(
      tester,
      const PaintListReadiness(total: 0, inStock: 0, low: 0, missing: 0),
    );

    expect(_segments(), findsNothing);
  });
}
