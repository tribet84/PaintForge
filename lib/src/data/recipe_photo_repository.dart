import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Persistence boundary for recipe cover photos.
///
/// Photos live in Cloud Storage rather than inside the recipe document: a
/// Firestore document is capped at 1 MiB shared with every other field, and
/// the image would be re-downloaded with the recipe on every read.
abstract class RecipePhotoRepository {
  /// Uploads [bytes] and returns the download URL to store on the recipe.
  Future<String> upload(Uint8List bytes);

  /// Removes a previously uploaded photo. Safe to call with a URL that is
  /// already gone.
  Future<void> deleteByUrl(String url);

  /// Removes every photo this user has uploaded — used when the whole
  /// account is deleted.
  Future<void> deleteAll();
}

class FirebaseRecipePhotoRepository implements RecipePhotoRepository {
  FirebaseRecipePhotoRepository({required this.uid, FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final String uid;
  final FirebaseStorage _storage;

  Reference get _folder => _storage.ref('users/$uid/recipePhotos');

  @override
  Future<String> upload(Uint8List bytes) async {
    // Named by timestamp rather than by recipe id: a brand-new recipe has no
    // id until it is saved, and the editor uploads as part of saving.
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = _folder.child(name);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        // Photos are immutable once written — a change uploads a new object —
        // so they can be cached hard.
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (error) {
      // Already deleted, or a legacy value that is not a Storage URL at all.
      // Losing the object is not worth failing the user's action over.
      debugPrint('Recipe photo delete skipped: $error');
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final listing = await _folder.listAll();
      await Future.wait(listing.items.map((item) => item.delete()));
    } catch (error) {
      debugPrint('Recipe photo cleanup skipped: $error');
    }
  }
}
