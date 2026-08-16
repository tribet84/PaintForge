import '../../l10n/generated/app_localizations.dart';
import '../models/paint_list.dart';

/// One-line breakdown of a readiness verdict.
///
/// Only non-zero parts are shown. "2 owned · 0 running low · 0 missing" spent
/// two thirds of the line telling the user nothing was wrong, burying the one
/// number that mattered.
String readinessDetailText(AppLocalizations l10n, PaintListReadiness r) {
  return [
    if (r.inStock > 0) l10n.listReadinessInStock(r.inStock),
    if (r.low > 0) l10n.listReadinessLow(r.low),
    if (r.missing > 0) l10n.listReadinessMissing(r.missing),
  ].join(' · ');
}
