import '../data/catalog_repository.dart';
import '../models/paint.dart';
import 'color_distance.dart';

/// A cross-brand equivalence, graded the way a painter would grade it.
enum MatchTier {
  /// Below deltaE 2: the eye cannot tell them apart.
  twin,

  /// Up to 5: an honest substitute.
  close,

  /// Up to 10: same neighbourhood, check before relying on it.
  approximate,
}

typedef PaintMatch = ({Paint paint, double deltaE, MatchTier tier});

/// How a paint behaves on the model, as far as the range name can tell.
///
/// Matching across these families is where numeric colour distance lies to
/// people: a gold and a brown can share a hex and share nothing on a mini,
/// and a wash's swatch is its dried-on-white tone, not a coat of paint.
/// paintRack matches across them anyway — it is their users' complaint
/// about metallic matches that taught us not to.
enum _Finish { opaque, metallic, translucent }

_Finish _finishOf(Paint paint) {
  final range = paint.range.toLowerCase();
  if (range.contains('metallic')) return _Finish.metallic;
  const translucent = [
    'contrast', 'shade', 'speedpaint', 'xpress', 'wash',
    'dipping ink', 'intensity ink', 'quickshade', '3gen ink',
  ];
  if (translucent.any(range.contains)) return _Finish.translucent;
  return _Finish.opaque;
}

/// The closest paints to [paint] from OTHER brands, best first.
///
/// Same-brand neighbours are excluded on purpose: the question this answers
/// is "I follow a recipe written in Citadel and I own Vallejo", never "what
/// else does my own brand sell".
List<PaintMatch> crossBrandMatches(
  CatalogRepository catalog,
  Paint paint, {
  int limit = 3,
}) {
  return _closest(
    catalog.paints.where((c) => c.brand != paint.brand),
    paint,
    limit: limit,
  );
}

/// The closest substitutes for [paint] among the pots the user already OWNS.
///
/// This is the money question: the recipe names a paint that is not on the
/// shelf — which of MY bottles gets me there without buying anything?
/// Unlike [crossBrandMatches], the same brand is welcome here: a substitute
/// you own beats a purchase from any brand.
List<PaintMatch> shelfSubstitutes(
  CatalogRepository catalog,
  Set<String> ownedIds,
  Paint paint, {
  int limit = 3,
}) {
  return _closest(
    catalog.paints
        .where((c) => c.id != paint.id && ownedIds.contains(c.id)),
    paint,
    limit: limit,
  );
}

List<PaintMatch> _closest(
  Iterable<Paint> candidates,
  Paint paint, {
  required int limit,
}) {
  final color = paint.color;
  if (color == null) return const [];

  final target = labFromColor(color);
  final finish = _finishOf(paint);

  final scored = <({Paint paint, double deltaE})>[];
  for (final candidate in candidates) {
    if (_finishOf(candidate) != finish) continue;
    final candidateColor = candidate.color;
    if (candidateColor == null) continue;
    scored.add((
      paint: candidate,
      deltaE: deltaE2000(target, labFromColor(candidateColor)),
    ));
  }
  scored.sort((a, b) => a.deltaE.compareTo(b.deltaE));

  return [
    for (final s in scored.take(limit))
      // Past 10 the honest answer is "no equivalent", not a bad one.
      if (s.deltaE < 10)
        (
          paint: s.paint,
          deltaE: s.deltaE,
          tier: s.deltaE < 2
              ? MatchTier.twin
              : s.deltaE < 5
                  ? MatchTier.close
                  : MatchTier.approximate,
        ),
  ];
}
