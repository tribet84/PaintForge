import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/image_compressor.dart';
import '../services/photo_cdn.dart';

/// Renders a recipe's cover photo from whichever source it has.
///
/// New photos live in Cloud Storage and are referenced by URL; recipes saved
/// before Storage was available carry base64 in the document instead. Both
/// have to keep working, so the choice lives in one place rather than in
/// every screen that shows a picture.
class RecipePhoto extends StatelessWidget {
  const RecipePhoto({
    super.key,
    required this.recipe,
    required this.height,
    this.borderRadius,
  });

  final Recipe recipe;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = recipe.photoUrl;
    final legacy = decodePhoto(recipe.photo);

    Widget? image;
    if (url != null && url.isNotEmpty) {
      image = Image.network(
        cdnPhotoUrl(url),
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
    } else if (legacy != null) {
      image = Image.memory(
        legacy,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    if (image == null) return const SizedBox.shrink();
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
