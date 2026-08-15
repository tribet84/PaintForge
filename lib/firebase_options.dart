import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Placeholder until you generate the real file.
///
/// Run:
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// The CLI overwrites this file with your project's real [FirebaseOptions]
/// for every platform. Until then the app starts in "setup pending" mode
/// and shows instructions instead of the login screen.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'DefaultFirebaseOptions has not been configured yet. '
      'Run `flutterfire configure` to generate lib/firebase_options.dart '
      'for your Firebase project.',
    );
  }
}
