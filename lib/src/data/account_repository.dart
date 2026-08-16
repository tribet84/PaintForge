import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_photo_repository.dart';

/// Persistence boundary for wiping a user's Firestore data.
///
/// Deleting the Firebase Auth account itself is a separate step (see
/// `AuthService.deleteAccount`) — this repository only handles the data, and
/// must run BEFORE the auth account is deleted: once the account is gone the
/// user's ID token is invalidated and these writes would be rejected.
abstract class AccountRepository {
  Future<void> deleteAllData();
}

class FirestoreAccountRepository implements AccountRepository {
  FirestoreAccountRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    RecipePhotoRepository? photos,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _photos = photos;

  final String uid;
  final FirebaseFirestore _firestore;
  final RecipePhotoRepository? _photos;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(uid);

  @override
  Future<void> deleteAllData() async {
    await _deleteAllDocs(_userDoc.collection('inventory'));
    await _deleteAllDocs(_userDoc.collection('paintLists'));

    // Unpublish everything this user shared so it disappears for anyone who
    // linked it, and no orphaned public document is left behind.
    final ownedPublications = await _firestore
        .collection('publishedRecipes')
        .where('ownerUid', isEqualTo: uid)
        .get();
    for (final doc in ownedPublications.docs) {
      await _deleteAllDocs(doc.reference.collection('links'));
      await doc.reference.delete();
    }

    await _deleteAllDocs(_userDoc.collection('recipes'));

    // Remove this user's own link markers from OTHER painters' published
    // recipes before dropping the bookmarks that point to them.
    final linked = await _userDoc.collection('linkedRecipes').get();
    for (final doc in linked.docs) {
      await _firestore
          .collection('publishedRecipes')
          .doc(doc.id)
          .collection('links')
          .doc(uid)
          .delete();
    }
    await _deleteAllDocs(_userDoc.collection('linkedRecipes'));

    // Uploaded photos are user data too, and Storage does not cascade with
    // the Firestore documents that referenced them.
    await _photos?.deleteAll();

    await _userDoc.delete();
  }

  Future<void> _deleteAllDocs(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    // Firestore batches cap at 500 writes; chunk defensively even though a
    // hobby account is very unlikely to ever hit that size.
    const chunkSize = 400;
    while (true) {
      final snapshot = await collection.limit(chunkSize).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < chunkSize) return;
    }
  }
}
