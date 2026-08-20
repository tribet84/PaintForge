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

/// Opens the user's mail client with a draft to [address].
Future<bool> openMailTo(String address, {String? subject}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
