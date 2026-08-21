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

  /// Every recipe this author currently has published, newest first.
  ///
  /// Backs the author page — reachable only from a recipe the viewer
  /// already holds a link to, so a short list reads as a person's shelf,
  /// never as an empty marketplace. Sorted client-side: the list is
  /// human-sized and a composite index would be infrastructure for nothing.
  Future<List<PublishedRecipe>> byAuthor(String ownerUid);

  /// Ids of the public recipes the user has linked into their account.
  Stream<List<String>> watchLinkedIds();

  Future<void> link(String publishedId);

  Future<void> unlink(String publishedId);

  /// How many painters have linked this recipe.
  Future<int> linkCount(String publishedId);

  /// Authors this user follows, with the watermark of what they have
  /// already seen from each.
  Stream<List<Follow>> watchFollowing();

  /// Start following [authorUid]. Sets the seen-watermark to now on
  /// purpose: following someone is a subscription to their FUTURE work,
  /// not a bell that immediately rings for their whole back catalogue.
  Future<void> follow(String authorUid, String authorName);

  Future<void> unfollow(String authorUid);

  /// How many painters follow [authorUid].
  Future<int> followerCount(String authorUid);

  /// Moves the seen-watermark of every followed author to now.
  Future<void> markAllSeen();
}

/// An author the user follows.
typedef Follow = ({String authorUid, String authorName, DateTime seenUpTo});

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
        if (recipe.photoUrl != null) 'photoUrl': recipe.photoUrl,
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
    return _published
        .doc(publishedId)
        .snapshots()
        .map((snapshot) => _fromData(snapshot.id, snapshot.data()));
  }

  @override
  Future<List<PublishedRecipe>> byAuthor(String ownerUid) async {
    final snapshot =
        await _published.where('ownerUid', isEqualTo: ownerUid).get();
    final recipes = [
      for (final doc in snapshot.docs)
        if (_fromData(doc.id, doc.data()) case final recipe?) recipe,
    ]..sort((a, b) => b.recipe.updatedAt.compareTo(a.recipe.updatedAt));
    return recipes;
  }

  /// One parser for every read path, so the author page can never disagree
  /// with the single-recipe view about what a published doc means.
  PublishedRecipe? _fromData(String id, Map<String, dynamic>? data) {
    final ownerUid = data?['ownerUid'] as String?;
    final name = data?['name'] as String?;
    if (data == null || ownerUid == null || name == null) return null;
    return PublishedRecipe(
      id: id,
      ownerUid: ownerUid,
      authorName: data['authorName'] as String? ?? '',
      recipe: Recipe(
        id: id,
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
        photoUrl: data['photoUrl'] as String?,
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ),
    );
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

  CollectionReference<Map<String, dynamic>> get _following =>
      _firestore.collection('users').doc(uid).collection('following');

  DocumentReference<Map<String, dynamic>> _followerMarker(
    String authorUid,
  ) =>
      _firestore
          .collection('follows')
          .doc(authorUid)
          .collection('followers')
          .doc(uid);

  @override
  Stream<List<Follow>> watchFollowing() {
    return _following.snapshots().map((snapshot) => [
          for (final doc in snapshot.docs)
            (
              authorUid: doc.id,
              authorName: doc.data()['authorName'] as String? ?? '',
              seenUpTo: (doc.data()['seenUpTo'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
        ]);
  }

  @override
  Future<void> follow(String authorUid, String authorName) {
    // One batch so the private list and the public marker (the author's
    // follower count) can never drift apart — same discipline as link().
    final batch = _firestore.batch()
      ..set(_following.doc(authorUid), {
        'authorName': authorName,
        'seenUpTo': FieldValue.serverTimestamp(),
      })
      ..set(_followerMarker(authorUid), {
        'followedAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }

  @override
  Future<void> unfollow(String authorUid) {
    final batch = _firestore.batch()
      ..delete(_following.doc(authorUid))
      ..delete(_followerMarker(authorUid));
    return batch.commit();
  }

  @override
  Future<int> followerCount(String authorUid) async {
    final snapshot = await _firestore
        .collection('follows')
        .doc(authorUid)
        .collection('followers')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<void> markAllSeen() async {
    final snapshot = await _following.get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'seenUpTo': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }
}
