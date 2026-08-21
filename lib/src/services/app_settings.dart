import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local settings: things that describe THIS install, not the account.
///
/// Deliberately not in Firestore. The language of a phone and whether a hint
/// was dismissed on it belong to the device — syncing them would force one
/// device's choice onto another (a Spanish phone and an English tablet are
/// both correct at once).
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  static const _localeKey = 'localeOverride';
  static const _paintCardHintKey = 'paintCardHintDismissed';
  static const _shelfStarterKey = 'shelfStarterDismissed';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings(await SharedPreferences.getInstance());

  /// Null means "follow the system", which is the default and the right
  /// answer for almost everyone. The override exists for the mismatch case:
  /// a phone set to English owned by someone who paints in Spanish.
  Locale? get localeOverride {
    final code = _prefs.getString(_localeKey);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, locale.languageCode);
    }
    notifyListeners();
  }

  /// One-shot hint teaching that a catalogue row opens the paint card.
  /// Dismissal is permanent per device: a hint that resurrects is nagging.
  bool get paintCardHintDismissed =>
      _prefs.getBool(_paintCardHintKey) ?? false;

  Future<void> dismissPaintCardHint() async {
    await _prefs.setBool(_paintCardHintKey, true);
    notifyListeners();
  }

  /// Set when the user walks away from the guided shelf starter. "I'd
  /// rather browse on my own" is an answer, not a postponement — the
  /// starter used to come back on every visit while the shelf stayed
  /// empty, which turned a one-time offer into a recurring toll booth.
  bool get shelfStarterDismissed => _prefs.getBool(_shelfStarterKey) ?? false;

  Future<void> dismissShelfStarter() async {
    await _prefs.setBool(_shelfStarterKey, true);
    notifyListeners();
  }
}
