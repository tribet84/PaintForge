import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/recipe_repository.dart';
import 'sample_recipe.dart';

/// Seeds the example recipe into brand-new accounts, exactly once.
///
/// The one-shot flag lives on the user's root document rather than being
/// inferred from "no recipes yet", so deleting the example does not bring it
/// back on the next launch.
class SampleRecipeSeeder {
  SampleRecipeSeeder({
    required this.uid,
    required RecipeRepository recipes,
    FirebaseFirestore? firestore,
  })  : _recipes = recipes,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final RecipeRepository _recipes;
  final FirebaseFirestore _firestore;

  Future<void> seedIfNeeded(String languageCode) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final snapshot = await userDoc.get();
      if ((snapshot.data() ?? const {})['sampleRecipeSeeded'] == true) return;
      // Flag first: if the recipe write raced or failed we would rather skip
      // the sample than ever create it twice.
      await userDoc.set({'sampleRecipeSeeded': true}, SetOptions(merge: true));
      await _recipes.create(buildSampleRecipe(languageCode));
    } catch (error) {
      // Seeding is a nicety — never let it break startup.
      debugPrint('Sample recipe seeding failed: $error');
    }
  }
}
