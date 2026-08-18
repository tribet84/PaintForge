import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/share_links.dart';

/// The legal link is the only route a user has to the privacy policy from
/// inside the app, and a broken one silently defeats the point of publishing
/// the documents at all.
void main() {
  test('the legal link is a real absolute URL on the app domain', () {
    expect(kLegalUrl, 'https://pintaminis.com/legal/');
    expect(kLegalUrl, isNot(contains(r'$')),
        reason: 'an uninterpolated placeholder would ship a dead link');
    expect(Uri.tryParse(kLegalUrl)?.hasScheme, isTrue);
  });
}
