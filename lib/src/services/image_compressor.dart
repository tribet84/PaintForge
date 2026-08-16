import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Why a picked photo could not be stored.
enum PhotoRejection {
  /// The bytes were not a picture this app can decode.
  unreadable,

  /// Even at the lowest quality it would not fit the storage budget.
  stillTooLarge,
}

class PhotoCompressionException implements Exception {
  const PhotoCompressionException(this.reason);
  final PhotoRejection reason;
}

/// Compresses a picked photo before it is uploaded.
///
/// Photos now go to Cloud Storage rather than into the recipe document, so
/// the budget is no longer squeezed by Firestore's 1 MiB per-document cap and
/// can afford a sharper image. It stays a HARD limit regardless: compression
/// happens on the device, so a 20 MB camera photo never leaves the phone at
/// full size, and neither the user's data plan nor the project's egress pays
/// for it.
class ImageCompressor {
  const ImageCompressor({
    this.maxDimension = 1600,
    this.maxBytes = 600 * 1024,
    this.initialQuality = 85,
    this.minQuality = 45,
  });

  /// Longest edge of the stored image, in pixels.
  final int maxDimension;

  /// Hard ceiling for the encoded JPEG, before base64 expansion.
  final int maxBytes;

  final int initialQuality;
  final int minQuality;

  /// Base64 grows by roughly 4/3, so this is what the document actually pays.
  int get maxEncodedBytes => (maxBytes * 4 / 3).ceil();

  /// Smallest longest-edge this will shrink to before giving up. Below this
  /// the photo stops being worth keeping.
  final int minDimension = 256;

  /// Decodes, downscales and re-encodes [bytes] until it fits [maxBytes].
  ///
  /// Lowering JPEG quality alone is NOT enough: a sufficiently detailed photo
  /// stays over budget even at the lowest quality this accepts, so each round
  /// of quality steps is followed by halving the dimensions. That guarantees
  /// convergence instead of rejecting photos a user could reasonably expect
  /// to work.
  ///
  /// Throws [PhotoCompressionException] rather than silently storing
  /// something oversized.
  Uint8List compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const PhotoCompressionException(PhotoRejection.unreadable);
    }

    // Only ever shrink: upscaling a small photo would add bytes for nothing.
    final longestEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    var targetEdge = longestEdge > maxDimension ? maxDimension : longestEdge;

    while (true) {
      final candidate = targetEdge >= longestEdge
          ? decoded
          : img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? targetEdge : null,
              height: decoded.height > decoded.width ? targetEdge : null,
              interpolation: img.Interpolation.average,
            );

      for (var quality = initialQuality;
          quality >= minQuality;
          quality -= 15) {
        final encoded = img.encodeJpg(candidate, quality: quality);
        if (encoded.length <= maxBytes) return encoded;
      }

      if (targetEdge <= minDimension) {
        throw const PhotoCompressionException(PhotoRejection.stillTooLarge);
      }
      final halved = targetEdge ~/ 2;
      targetEdge = halved < minDimension ? minDimension : halved;
    }
  }

  /// Compresses and encodes ready for Firestore.
  String compressToBase64(Uint8List bytes) => base64Encode(compress(bytes));
}

/// Decodes a stored photo back into bytes for display.
///
/// Returns null on anything malformed so a corrupt value degrades to "no
/// photo" instead of crashing the recipe screen.
Uint8List? decodePhoto(String? base64Photo) {
  if (base64Photo == null || base64Photo.isEmpty) return null;
  try {
    return base64Decode(base64Photo);
  } on FormatException {
    return null;
  }
}
