import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';

/// Persistence boundary for painting recipes.
abstract class RecipeRepository {
  /// Most recently updated first.
  Stream<List<Recipe>> watchRecipes();

  /// Returns the id of the created recipe. The [recipe]'s own id is ignored.
  Future<String> create(Recipe recipe);

  Future<void> update(Recipe recipe);

  Future<void> delete(String recipeId);
}

/// Firestore-backed recipes, one document per recipe under
/// `users/{uid}/recipes/{recipeId}`.
class FirestoreRecipeRepository implements RecipeRepository {
  FirestoreRecipeRepository({required this.uid, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(uid).collection('recipes');

  @override
  Stream<List<Recipe>> watchRecipes() {
    return _collection.snapshots().map((snapshot) {
      final recipes = <Recipe>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        if (name == null) continue;
        recipes.add(
          Recipe(
            id: doc.id,
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
            publishedId: data['publishedId'] as String?,
            // Null while a server timestamp is still pending locally.
            updatedAt:
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );
      }
      recipes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return recipes;
    });
  }

  @override
  Future<String> create(Recipe recipe) async {
    final doc = await _collection.add({
      ...recipe.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> update(Recipe recipe) {
    return _collection.doc(recipe.id).set({
      ...recipe.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String recipeId) => _collection.doc(recipeId).delete();
}
