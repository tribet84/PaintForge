import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/install_hint_logic.dart';

/// The install hint's whole value is restraint. Each case here is a way it
/// could become annoying, pinned shut.
void main() {
  test('a first visit is too early to ask anything of anyone', () {
    expect(
      shouldShowInstallHint(visits: 1, standalone: false, dismissed: false),
      isFalse,
    );
  });

  test('someone who came back has a reason to keep the app around', () {
    expect(
      shouldShowInstallHint(visits: 2, standalone: false, dismissed: false),
      isTrue,
    );
  });

  test('already installed means never ask again', () {
    expect(
      shouldShowInstallHint(visits: 5, standalone: true, dismissed: false),
      isFalse,
    );
  });

  test('a dismissal is an answer, not an obstacle', () {
    expect(
      shouldShowInstallHint(visits: 5, standalone: false, dismissed: true),
      isFalse,
    );
  });
}
