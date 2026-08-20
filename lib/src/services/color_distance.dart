/// Perceptual colour distance, the way paintRack learned to do it the hard
/// way: their hue-based matcher was "naive" (their word), Euclidean RGB
/// "similarly flawed", and CIEDE2000 is where they landed. We start there.
///
/// The scale is the one colour science gives us: below ~2 two paints are
/// indistinguishable to the eye, up to ~5 they are honest substitutes, and
/// past 10 calling them a match would be lying.
///
/// Everything here is a pure function on purpose — the implementation is
/// verified against Sharma's canonical CIEDE2000 test pairs, which is only
/// possible when nothing touches a widget or a catalogue.
library;

import 'dart:math' as math;
import 'dart:ui';

/// CIE L*a*b* coordinates for a colour, D65 illuminant.
typedef Lab = ({double l, double a, double b});

/// sRGB → CIELAB. The gamma expansion matters: skipping it (treating sRGB
/// as linear) shifts every dark colour and quietly breaks the distances.
Lab labFromColor(Color color) {
  double lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  final r = lin(color.r);
  final g = lin(color.g);
  final b = lin(color.b);

  final x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  final y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
  final z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883;

  double f(double t) => t > 0.008856451679035631
      ? math.pow(t, 1 / 3).toDouble()
      : t / (3 * 0.04280618311533888) + 4 / 29;

  final fx = f(x), fy = f(y), fz = f(z);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

/// CIEDE2000 colour difference (Sharma et al. formulation).
double deltaE2000(Lab c1, Lab c2) {
  const pow25_7 = 6103515625.0; // 25^7

  final cAvg = (math.sqrt(c1.a * c1.a + c1.b * c1.b) +
          math.sqrt(c2.a * c2.a + c2.b * c2.b)) /
      2;
  final g = 0.5 *
      (1 -
          math.sqrt(math.pow(cAvg, 7) / (math.pow(cAvg, 7) + pow25_7)));

  final a1p = c1.a * (1 + g), a2p = c2.a * (1 + g);
  final c1p = math.sqrt(a1p * a1p + c1.b * c1.b);
  final c2p = math.sqrt(a2p * a2p + c2.b * c2.b);

  double hue(double a, double b) {
    if (a == 0 && b == 0) return 0;
    final h = math.atan2(b, a) * 180 / math.pi;
    return h < 0 ? h + 360 : h;
  }

  final h1p = hue(a1p, c1.b), h2p = hue(a2p, c2.b);

  final dLp = c2.l - c1.l;
  final dCp = c2p - c1p;

  double dhp;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if ((h2p - h1p).abs() <= 180) {
    dhp = h2p - h1p;
  } else if (h2p - h1p > 180) {
    dhp = h2p - h1p - 360;
  } else {
    dhp = h2p - h1p + 360;
  }
  final dHp =
      2 * math.sqrt(c1p * c2p) * math.sin(dhp * math.pi / 360);

  final lAvg = (c1.l + c2.l) / 2;
  final cpAvg = (c1p + c2p) / 2;

  double hpAvg;
  if (c1p * c2p == 0) {
    hpAvg = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hpAvg = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hpAvg = (h1p + h2p + 360) / 2;
  } else {
    hpAvg = (h1p + h2p - 360) / 2;
  }

  double cosDeg(double d) => math.cos(d * math.pi / 180);
  final t = 1 -
      0.17 * cosDeg(hpAvg - 30) +
      0.24 * cosDeg(2 * hpAvg) +
      0.32 * cosDeg(3 * hpAvg + 6) -
      0.20 * cosDeg(4 * hpAvg - 63);

  final sl = 1 +
      0.015 * math.pow(lAvg - 50, 2) / math.sqrt(20 + math.pow(lAvg - 50, 2));
  final sc = 1 + 0.045 * cpAvg;
  final sh = 1 + 0.015 * cpAvg * t;

  final dTheta = 30 * math.exp(-math.pow((hpAvg - 275) / 25, 2));
  final rc = 2 *
      math.sqrt(math.pow(cpAvg, 7) / (math.pow(cpAvg, 7) + pow25_7));
  final rt = -rc * math.sin(2 * dTheta * math.pi / 180);

  final tl = dLp / sl, tc = dCp / sc, th = dHp / sh;
  return math.sqrt(tl * tl + tc * tc + th * th + rt * tc * th);
}
