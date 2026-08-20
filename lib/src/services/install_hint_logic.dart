/// Decides whether to suggest installing the app to the home screen.
///
/// Pure on purpose: the browser-dependent inputs (visit count, standalone
/// display mode, a stored dismissal) are gathered elsewhere, so this rule —
/// the actual product decision — can be unit-tested on any platform.
///
/// Why each input earns its place: a first visit is too early to ask
/// anything of anyone; someone who came back has a reason to keep the app
/// around. Standalone mode means it is already installed, and asking again
/// would prove we are not paying attention. And a dismissal is an answer,
/// not an obstacle — asked once, declined, never again.
bool shouldShowInstallHint({
  required int visits,
  required bool standalone,
  required bool dismissed,
}) {
  return !standalone && !dismissed && visits >= 2;
}
