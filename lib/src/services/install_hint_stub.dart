import 'install_hint_logic.dart';

/// Non-web platforms install through an app store, not a browser hint.
bool shouldOfferInstallHint() => false;

void dismissInstallHint() {}

// Referenced so the conditional export stays honest about what is shared.
// ignore: unused_element
final _logic = shouldShowInstallHint;
