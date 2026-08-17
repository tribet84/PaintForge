import 'package:flutter/foundation.dart' show visibleForTesting;

/// Where the web app lives; shared recipe links point here.
///
/// The custom domain rather than the Firebase one: a shared link is the most
/// public thing the app produces, and it outlives whatever hosting sits
/// behind it. The `.web.app` address still serves the same site, so links
/// already out there keep working.
const kAppUrl = 'https://pintaminis.com';

/// Shareable URL for a published recipe.
///
/// Uses the hash fragment so it works with Flutter web's default URL
/// strategy and never depends on hosting rewrites.
String publicRecipeUrl(String publishedId) => '$kAppUrl/#/r/$publishedId';

/// Extracts the published-recipe id from a URL the app was opened with,
/// accepting both `/#/r/{id}` and `/r/{id}` forms.
String? publicRecipeIdFromUri(Uri uri) {
  final source = uri.fragment.isNotEmpty ? uri.fragment : uri.path;
  return RegExp(r'/r/([A-Za-z0-9_-]+)').firstMatch(source)?.group(1);
}

/// The share link the app was launched with, if any.
///
/// [capture] MUST run at the very top of `main()`, before the Flutter engine
/// is initialised: on web the engine takes over the URL as part of its
/// routing setup, so reading `Uri.base` later can find the fragment already
/// normalised away and the link silently lost.
///
/// [consume] then hands it over exactly once, so signing into a different
/// account does not re-open the same screen.
class PendingShareLink {
  PendingShareLink._();

  static String? _publishedId;
  static bool _consumed = false;

  static void capture() {
    _publishedId = publicRecipeIdFromUri(Uri.base);
  }

  /// Test seam: pretend the app was launched with [uri].
  @visibleForTesting
  static void captureFrom(Uri uri) {
    _publishedId = publicRecipeIdFromUri(uri);
    _consumed = false;
  }

  @visibleForTesting
  static void reset() {
    _publishedId = null;
    _consumed = false;
  }

  static String? consume() {
    if (_consumed) return null;
    _consumed = true;
    return _publishedId;
  }
}
