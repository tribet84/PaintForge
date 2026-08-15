import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google AdMob integration, disabled by default.
///
/// Build with `--dart-define=ENABLE_ADS=true` to turn ads on. The ad unit
/// IDs below are Google's official TEST ids — replace them with your real
/// AdMob unit ids (and the app ids in AndroidManifest.xml / Info.plist)
/// before releasing with ads enabled.
class AdsService {
  static const bool adsEnabled = bool.fromEnvironment('ENABLE_ADS');

  /// Banners are only supported on Android/iOS.
  static bool get bannersAvailable =>
      adsEnabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';

  static Future<void> initialize() async {
    if (!bannersAvailable) return;
    await MobileAds.instance.initialize();
  }
}
