/// Identifies the exact bundle running, so a stale cache is provable rather
/// than a guess.
///
/// Injected by the build with:
/// `flutter build web --release --dart-define=BUILD_STAMP=...`
/// Falls back to "dev" for local runs that do not pass it.
const buildStamp = String.fromEnvironment('BUILD_STAMP', defaultValue: 'dev');
