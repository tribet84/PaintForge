import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/color_distance.dart';

/// Verified against Sharma et al.'s canonical CIEDE2000 test data — the
/// published pairs every correct implementation must reproduce. An almost-
/// right implementation still sorts matches wrongly, and the whole feature
/// is the sorting.
void main() {
  const cases = [
    // (L1, a1, b1, L2, a2, b2, expected dE2000) — Sharma pairs 1-4, 17, 24
    (50.0, 2.6772, -79.7751, 50.0, 0.0, -82.7485, 2.0425),
    (50.0, 3.1571, -77.2803, 50.0, 0.0, -82.7485, 2.8615),
    (50.0, 2.8361, -74.0200, 50.0, 0.0, -82.7485, 3.4412),
    (50.0, -1.3802, -84.2814, 50.0, 0.0, -82.7485, 1.0000),
    (50.0, 2.5000, 0.0000, 50.0, 3.1736, 0.5854, 1.0000),
    (60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387, 1.2644),
  ];

  test('reproduces the canonical Sharma test pairs to 4 decimals', () {
    for (final (l1, a1, b1, l2, a2, b2, expected) in cases) {
      final d = deltaE2000((l: l1, a: a1, b: b1), (l: l2, a: a2, b: b2));
      expect(d, closeTo(expected, 0.0001),
          reason: 'pair ($l1,$a1,$b1)/($l2,$a2,$b2)');
    }
  });

  test('is symmetric and zero on identity', () {
    const x = (l: 50.0, a: 2.6772, b: -79.7751);
    const y = (l: 50.0, a: 0.0, b: -82.7485);
    expect(deltaE2000(x, x), 0);
    expect(deltaE2000(x, y), closeTo(deltaE2000(y, x), 1e-12));
  });

  test('sRGB conversion hits the LAB anchors', () {
    final white = labFromColor(const Color(0xFFFFFFFF));
    expect(white.l, closeTo(100, 0.01));
    expect(white.a, closeTo(0, 0.01));
    expect(white.b, closeTo(0, 0.01));

    final black = labFromColor(const Color(0xFF000000));
    expect(black.l, closeTo(0, 0.01));

    // Pure sRGB red, published reference: L*≈53.24, a*≈80.09, b*≈67.20.
    final red = labFromColor(const Color(0xFFFF0000));
    expect(red.l, closeTo(53.24, 0.1));
    expect(red.a, closeTo(80.09, 0.1));
    expect(red.b, closeTo(67.20, 0.1));
  });
}
