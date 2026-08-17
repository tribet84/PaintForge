/// Host that serves recipe photos through the CDN, empty when disabled.
///
/// Injected at build time (`--dart-define=PHOTO_CDN_HOST=img.pintaminis.com`)
/// rather than hardcoded, so the CDN can be turned off for a build without a
/// code change if it ever misbehaves.
const kPhotoCdnHost = String.fromEnvironment('PHOTO_CDN_HOST');

/// The host Firebase Storage hands out download URLs on.
const _storageHost = 'firebasestorage.googleapis.com';

/// Rewrites a Firebase Storage download URL to go through the CDN.
///
/// Applied when the photo is DISPLAYED, never when it is stored: the
/// Storage URL stays the single source of truth in Firestore. Turning the
/// CDN off is then a build flag rather than a data migration, and a recipe
/// saved today keeps rendering if the CDN host ever disappears.
///
/// The path and query string — including the access token that authorizes
/// the download — are preserved untouched, so the CDN cannot widen access
/// to anything the original URL did not already grant.
String cdnPhotoUrl(String url) {
  if (kPhotoCdnHost.isEmpty) return url;

  final uri = Uri.tryParse(url);
  // Anything that is not a Storage download URL is left alone: legacy
  // values, and any future photo source, must not be silently rerouted.
  if (uri == null || uri.host != _storageHost) return url;

  return uri.replace(host: kPhotoCdnHost).toString();
}
