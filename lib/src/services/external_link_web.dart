import 'package:web/web.dart' as web;

/// Opens [url] in a new browser tab.
///
/// Deliberately does NOT use `url_launcher` on web. Its web implementation
/// calls `window.open(url, target, 'noopener,noreferrer')`, and per the HTML
/// spec a non-empty window-features string makes the browser treat the result
/// as a *popup* — which Chrome on Android blocks by default, so the link
/// silently did nothing.
///
/// Clicking a synthetic anchor with `target="_blank"` is a normal navigation
/// rather than a popup, so it is not subject to popup blocking. `rel` still
/// carries `noopener noreferrer` so the opened page cannot reach back into
/// this one through `window.opener`.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  // Only ever hand http(s) to the browser: a `javascript:` URL pasted into a
  // recipe link must never be navigated to.
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

/// Opens the user's mail client with a draft to [address].
///
/// Separate from [openExternalLink] on purpose: that function refuses
/// non-http(s) schemes as a safety net against `javascript:` URLs pasted
/// into recipes, and a mailto: would be silently swallowed by it. Here the
/// address is a compile-time constant of ours, not user input.
Future<bool> openMailTo(String address, {String? subject}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
  );
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = uri.toString()
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
