import 'package:web/web.dart' as web;

import 'install_hint_logic.dart';

const _visitsKey = 'pintaminis-visits';
const _dismissedKey = 'pintaminis-a2hs-dismissed';
const _sessionKey = 'pintaminis-visit-counted';

/// Gathers the browser facts and applies the shared rule.
///
/// The visit counter increments once per browser session — counting every
/// page build would call a single sitting many "visits" and fire the hint
/// on day one.
bool shouldOfferInstallHint() {
  try {
    final storage = web.window.localStorage;
    var visits = int.tryParse(storage.getItem(_visitsKey) ?? '') ?? 0;
    if (web.window.sessionStorage.getItem(_sessionKey) == null) {
      web.window.sessionStorage.setItem(_sessionKey, '1');
      visits += 1;
      storage.setItem(_visitsKey, '$visits');
    }
    return shouldShowInstallHint(
      visits: visits,
      standalone:
          web.window.matchMedia('(display-mode: standalone)').matches,
      dismissed: storage.getItem(_dismissedKey) != null,
    );
  } catch (_) {
    // Storage blocked (private mode): no hint beats a crash on startup.
    return false;
  }
}

void dismissInstallHint() {
  try {
    web.window.localStorage.setItem(_dismissedKey, '1');
  } catch (_) {}
}
