import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app.
///
/// On mobile and desktop this hands off to the OS, so a YouTube link opens in
/// the YouTube app when it is installed.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
