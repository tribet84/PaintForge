import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/image_compressor.dart';
import '../services/photo_cdn.dart';

/// The image behind a recipe's cover photo, whichever source it has.
///
/// New photos live in Cloud Storage and are referenced by URL; recipes saved
/// before Storage was available carry base64 in the document instead. Both
/// have to keep working, so the choice lives here rather than in every screen
/// that shows a picture — and sharing one provider means the thumbnail and
/// the full-screen view hit the same cache entry instead of downloading the
/// photo twice.
ImageProvider? recipePhotoProvider(Recipe recipe) {
  final url = recipe.photoUrl;
  if (url != null && url.isNotEmpty) return NetworkImage(cdnPhotoUrl(url));
  final legacy = decodePhoto(recipe.photo);
  if (legacy != null) return MemoryImage(legacy);
  return null;
}

/// A recipe's cover photo, cropped to fill [height].
class RecipePhoto extends StatelessWidget {
  const RecipePhoto({
    super.key,
    required this.recipe,
    required this.height,
    this.borderRadius,
    this.heroTag,
  });

  final Recipe recipe;
  final double height;
  final BorderRadius? borderRadius;

  /// Ties this thumbnail to the full-screen view it opens, so the photo
  /// grows out of the card instead of cutting to a new screen.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final provider = recipePhotoProvider(recipe);
    if (provider == null) return const SizedBox.shrink();

    Widget image = Image(
      image: provider,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              height: height,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      // A photo that fails to load must not take the card with it.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return image;
  }
}
