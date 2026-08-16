import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';

/// A recipe as seen by other painters: the public copy plus its author.
class PublishedRecipe {
  const PublishedRecipe({
    required this.id,
    required this.ownerUid,
    required this.authorName,
    required this.recipe,
  });

  final String id;
  final String ownerUid;
  final String authorName;

  /// The shared content. `recipe.updatedAt` is the author's last update —
  /// followers always see the latest version because links point here
  /// instead of cloning.
  final Recipe recipe;
}

/// Persistence boundary for the public sharing layer.
///
/// Publishing keeps a live copy under the top-level `publishedRecipes`
/// collection. Other users LINK to it (users/{uid}/linkedRecipes) rather than
/// cloning, so an author update reaches every linked account instantly, and a
/// marker doc under `publishedRecipes/{id}/links/{linkerUid}` makes the link
/// count computable without any server code.
abstract class PublishedRecipeRepository {
  /// Publishes [recipe] and returns the public id.
  Future<String> publish(Recipe recipe, {required String authorName});

  /// Pushes the latest content of an already-published recipe.
  Future<void> updatePublished(Recipe recipe, {required String authorName});

  Future<void> unpublish(String publishedId);

  Stream<PublishedRecipe?> watchPublished(String publishedId);

  /// Ids of the public recipes the user has linked into their account.
  Stream<List<String>> watchLinkedIds();

  Future<void> link(String publishedId);

  Future<void> unlink(String publishedId);

  /// How many painters have linked this recipe.
  Future<int> linkCount(String publishedId);
}

class FirestorePublishedRecipeRepository implements PublishedRecipeRepository {
  FirestorePublishedRecipeRepository({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _published =>
      _firestore.collection('publishedRecipes');

  CollectionReference<Map<String, dynamic>> get _linked =>
      _firestore.collection('users').doc(uid).collection('linkedRecipes');

  Map<String, dynamic> _publicMap(Recipe recipe, String authorName) => {
        'ownerUid': uid,
        'authorName': authorName,
        'name': recipe.name,
        'description': recipe.description,
        'sections': recipe.sections.map((s) => s.toMap()).toList(),
        'links': recipe.links.map((l) => l.toMap()).toList(),
        if (recipe.photo != null) 'photo': recipe.photo,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  Future<String> publish(Recipe recipe, {required String authorName}) async {
    final doc = await _published.add(_publicMap(recipe, authorName));
    return doc.id;
  }

  @override
  Future<void> updatePublished(Recipe recipe, {required String authorName}) {
    final publishedId = recipe.publishedId;
    if (publishedId == null) return Future.value();
    return _published.doc(publishedId).set(_publicMap(recipe, authorName));
  }

  @override
  Future<void> unpublish(String publishedId) async {
    // Clear the link markers first — followers keep an id in their own
    // linkedRecipes doc regardless, but PublicRecipeScreen already treats a
    // missing published doc as "no longer shared", so leaving them pointed at
    // a dead id is fine without a server-side fan-out.
    await _deleteAllDocs(_published.doc(publishedId).collection('links'));
    await _published.doc(publishedId).delete();
  }

  Future<void> _deleteAllDocs(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Stream<PublishedRecipe?> watchPublished(String publishedId) {
    return _published.doc(publishedId).snapshots().map((snapshot) {
      final data = snapshot.data();
      final ownerUid = data?['ownerUid'] as String?;
      final name = data?['name'] as String?;
      if (data == null || ownerUid == null || name == null) return null;
      return PublishedRecipe(
        id: snapshot.id,
        ownerUid: ownerUid,
        authorName: data['authorName'] as String? ?? '',
        recipe: Recipe(
          id: snapshot.id,
          name: name,
          description: data['description'] as String? ?? '',
          sections: (data['sections'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(RecipeSection.fromMap)
              .whereType<RecipeSection>()
              .toList(),
          links: (data['links'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(RecipeLink.fromMap)
              .whereType<RecipeLink>()
              .toList(),
          photo: data['photo'] as String?,
          updatedAt:
              (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ),
      );
    });
  }

  @override
  Stream<List<String>> watchLinkedIds() {
    return _linked.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toList(),
        );
  }

  @override
  Future<void> link(String publishedId) {
    // One batch so the personal link and the public marker (used for the
    // author's link count) never drift apart.
    final batch = _firestore.batch()
      ..set(_linked.doc(publishedId), {
        'linkedAt': FieldValue.serverTimestamp(),
      })
      ..set(_published.doc(publishedId).collection('links').doc(uid), {
        'linkedAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }

  @override
  Future<void> unlink(String publishedId) {
    final batch = _firestore.batch()
      ..delete(_linked.doc(publishedId))
      ..delete(_published.doc(publishedId).collection('links').doc(uid));
    return batch.commit();
  }

  @override
  Future<int> linkCount(String publishedId) async {
    final snapshot =
        await _published.doc(publishedId).collection('links').count().get();
    return snapshot.count ?? 0;
  }
}
