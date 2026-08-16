import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/published_recipe_repository.dart';
import '../data/recipe_photo_repository.dart';
import '../data/recipe_repository.dart';
import '../models/recipe.dart';

/// Holds the user's painting recipes and drives the public sharing layer.
class RecipesProvider extends ChangeNotifier {
  RecipesProvider({
    required RecipeRepository repository,
    PublishedRecipeRepository? publishedRepository,
    RecipePhotoRepository? photoRepository,
    String Function()? authorName,
  })  : _repository = repository,
        _publishedRepository = publishedRepository,
        _photoRepository = photoRepository,
        _authorName = authorName ?? (() => '') {
    _subscription = _repository.watchRecipes().listen((recipes) {
      _recipes = recipes;
      _loaded = true;
      notifyListeners();
    });
    _linkedSubscription =
        _publishedRepository?.watchLinkedIds().listen((ids) {
      _linkedIds = ids;
      notifyListeners();
    });
  }

  final RecipeRepository _repository;
  final PublishedRecipeRepository? _publishedRepository;
  final RecipePhotoRepository? _photoRepository;
  final String Function() _authorName;
  StreamSubscription<List<Recipe>>? _subscription;
  StreamSubscription<List<String>>? _linkedSubscription;

  List<Recipe> _recipes = const [];
  List<String> _linkedIds = const [];
  bool _loaded = false;

  bool get loaded => _loaded;

  List<Recipe> get recipes => _recipes;

  /// Public recipes from other painters linked into this account.
  List<String> get linkedIds => _linkedIds;

  Recipe? byId(String recipeId) {
    for (final recipe in _recipes) {
      if (recipe.id == recipeId) return recipe;
    }
    return null;
  }

  Future<String> create(Recipe recipe) => _repository.create(recipe);

  /// Saves the recipe and, if it is published, pushes the update to the
  /// public copy so every linked account sees the latest version.
  Future<void> update(Recipe recipe) async {
    await _repository.update(recipe);
    if (recipe.isPublished) {
      await _publishedRepository?.updatePublished(
        recipe,
        authorName: _authorName(),
      );
    }
  }

  Future<void> delete(Recipe recipe) async {
    if (recipe.isPublished) {
      await _publishedRepository?.unpublish(recipe.publishedId!);
    }
    await _repository.delete(recipe.id);
    // Last, so a failure here cannot leave a recipe pointing at a photo that
    // is already gone. An orphaned object costs pennies; a broken recipe does
    // not.
    final photoUrl = recipe.photoUrl;
    if (photoUrl != null) {
      await _photoRepository?.deleteByUrl(photoUrl);
    }
  }

  /// Publishes the recipe and returns the public id (existing one if it is
  /// already published).
  Future<String?> publish(Recipe recipe) async {
    final published = _publishedRepository;
    if (published == null) return null;
    if (recipe.isPublished) {
      await published.updatePublished(recipe, authorName: _authorName());
      return recipe.publishedId;
    }
    final publishedId =
        await published.publish(recipe, authorName: _authorName());
    await _repository.update(recipe.copyWith(publishedId: publishedId));
    return publishedId;
  }

  Future<void> unpublish(Recipe recipe) async {
    final publishedId = recipe.publishedId;
    if (publishedId == null) return;
    await _publishedRepository?.unpublish(publishedId);
    await _repository.update(recipe.copyWith(clearPublishedId: true));
  }

  Future<void> link(String publishedId) async {
    await _publishedRepository?.link(publishedId);
  }

  Future<void> unlink(String publishedId) async {
    await _publishedRepository?.unlink(publishedId);
  }

  bool isLinked(String publishedId) => _linkedIds.contains(publishedId);

  @override
  void dispose() {
    _subscription?.cancel();
    _linkedSubscription?.cancel();
    super.dispose();
  }
}
