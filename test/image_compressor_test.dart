import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paintforge/src/services/image_compressor.dart';

/// Builds a synthetic photo of the given size. Noise rather than flat colour,
/// so JPEG cannot compress it to almost nothing and the size limits are
/// actually exercised.
Uint8List syntheticPhoto(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      image.setPixelRgb(x, y, seed & 0xFF, (seed >> 8) & 0xFF, (seed >> 16) & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  const compressor = ImageCompressor();

  test('a large photo is shrunk below the byte ceiling', () {
    // Stands in for a phone camera shot: far bigger than we want to store.
    final original = syntheticPhoto(2400, 1800);
    expect(original.length, greaterThan(compressor.maxBytes));

    final result = compressor.compress(original);

    expect(result.length, lessThanOrEqualTo(compressor.maxBytes));
  });

  test('the longest edge is capped', () {
    final result = compressor.compress(syntheticPhoto(2400, 1200));
    final decoded = img.decodeImage(result)!;

    expect(decoded.width, compressor.maxDimension);
    expect(
      decoded.height,
      lessThanOrEqualTo(compressor.maxDimension),
    );
  });

  test('a portrait photo is capped on its height, keeping aspect ratio', () {
    final result = compressor.compress(syntheticPhoto(1200, 2400));
    final decoded = img.decodeImage(result)!;

    expect(decoded.height, compressor.maxDimension);
    expect(decoded.width, lessThan(decoded.height));
  });

  test('a small photo is not upscaled', () {
    final result = compressor.compress(syntheticPhoto(320, 240));
    final decoded = img.decodeImage(result)!;

    expect(decoded.width, 320);
    expect(decoded.height, 240);
  });

  test('non-image bytes are rejected, not stored', () {
    final garbage = Uint8List.fromList(List.filled(2048, 7));

    expect(
      () => compressor.compress(garbage),
      throwsA(
        isA<PhotoCompressionException>().having(
          (e) => e.reason,
          'reason',
          PhotoRejection.unreadable,
        ),
      ),
    );
  });

  test('base64 output stays within the documented encoded budget', () {
    final encoded = compressor.compressToBase64(syntheticPhoto(2400, 1800));

    expect(encoded.length, lessThanOrEqualTo(compressor.maxEncodedBytes));
    // Well clear of Firestore's 1 MiB per-document ceiling, which the photo
    // shares with every other recipe field.
    expect(encoded.length, lessThan(1024 * 1024));
  });

  group('decodePhoto', () {
    test('round-trips what the compressor produced', () {
      final encoded = compressor.compressToBase64(syntheticPhoto(800, 600));
      final decoded = decodePhoto(encoded);

      expect(decoded, isNotNull);
      expect(img.decodeImage(decoded!), isNotNull);
    });

    test('null and empty mean "no photo"', () {
      expect(decodePhoto(null), isNull);
      expect(decodePhoto(''), isNull);
    });

    test('a corrupt value degrades to no photo instead of throwing', () {
      expect(decodePhoto('not-valid-base64!!!'), isNull);
    });
  });

  test('a stricter budget forces harder compression', () {
    const strict = ImageCompressor(maxDimension: 512, maxBytes: 40 * 1024);
    final result = strict.compress(syntheticPhoto(2400, 1800));
    final decoded = img.decodeImage(result)!;

    expect(result.length, lessThanOrEqualTo(strict.maxBytes));
    expect(decoded.width, lessThanOrEqualTo(512));
  });

  test('base64 encoding is what actually lands in Firestore', () {
    final raw = compressor.compress(syntheticPhoto(1000, 1000));
    final encoded = compressor.compressToBase64(syntheticPhoto(1000, 1000));

    expect(base64Decode(encoded).length, raw.length);
  });
}
