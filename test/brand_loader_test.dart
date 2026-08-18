import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/widgets/brand_loader.dart';

/// The loader's whole point is restraint: it must not flash over work that
/// finishes quickly, and it must hold still for anyone who asked the system
/// to reduce motion.
void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  Future<double> opacityOf(WidgetTester tester) async {
    final w = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    return w.opacity;
  }

  testWidgets('stays invisible while the wait is still imperceptible',
      (tester) async {
    await tester.pumpWidget(wrap(const BrandLoader()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await opacityOf(tester), 0,
        reason: 'a loader that flashes up and vanishes reads as a glitch');
  });

  testWidgets('appears once the wait is long enough to notice', (tester) async {
    await tester.pumpWidget(wrap(const BrandLoader()));
    await tester.pump(const Duration(milliseconds: 350));

    expect(await opacityOf(tester), 1);
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('a zero delay shows the mark straight away', (tester) async {
    await tester.pumpWidget(wrap(const BrandLoader(delay: Duration.zero)));
    await tester.pump();

    expect(await opacityOf(tester), 1);
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('does not animate when the system asks to reduce motion',
      (tester) async {
    await tester.pumpWidget(
      wrap(const BrandLoader(delay: Duration.zero), disableAnimations: true),
    );
    await tester.pump();

    expect(
      find.byKey(BrandLoader.pulseKey),
      findsNothing,
      reason: 'a pulsing logo is decoration; stillness was requested',
    );
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('pulses by default', (tester) async {
    await tester.pumpWidget(wrap(const BrandLoader(delay: Duration.zero)));
    await tester.pump();

    expect(find.byKey(BrandLoader.pulseKey), findsOneWidget);
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('the label reaches screen readers as a live region',
      (tester) async {
    await tester.pumpWidget(
      wrap(const BrandLoader(delay: Duration.zero, label: 'Deleting…')),
    );
    await tester.pump();

    expect(find.text('Deleting…'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.ancestor(
        of: find.text('Deleting…'),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semantics.properties.liveRegion, isTrue);
    await tester.pumpWidget(wrap(const SizedBox()));
  });

  testWidgets('disposes its ticker without leaking', (tester) async {
    await tester.pumpWidget(wrap(const BrandLoader(delay: Duration.zero)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpAndSettle();
    // A surviving Timer or AnimationController fails the test automatically.
  });
}
