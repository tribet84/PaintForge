import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/photo_cdn.dart';

/// These run WITHOUT the PHOTO_CDN_HOST define, which is the default for
/// `flutter test`. That is deliberate: the contract worth pinning is that a
/// build with no CDN configured leaves every URL exactly as Storage handed
/// it out, so the feature can be switched off without breaking photos.
void main() {
  group('with no CDN host configured', () {
    test('kPhotoCdnHost defaults to empty', () {
      expect(kPhotoCdnHost, isEmpty);
    });

    test('a Storage download URL is returned untouched', () {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/paintforge-d8cf2.firebasestorage.app'
          '/o/users%2Fabc%2FrecipePhotos%2F123.jpg?alt=media&token=deadbeef';

      expect(cdnPhotoUrl(url), url);
    });

    test('a URL from any other host is left alone', () {
      const url = 'https://example.com/photo.jpg';

      expect(cdnPhotoUrl(url), url);
    });

    test('an unparseable value does not throw', () {
      expect(cdnPhotoUrl('not a url at all'), 'not a url at all');
      expect(cdnPhotoUrl(''), '');
    });
  });
}
