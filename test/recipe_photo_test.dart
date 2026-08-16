import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/recipe_photo_repository.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/state/recipes_provider.dart';

import 'fakes.dart';

class FakeRecipePhotoRepository implements RecipePhotoRepository {
  final uploaded = <Uint8List>[];
  final deletedUrls = <String>[];
  var deleteAllCalled = false;
  var nextUrl = 'https://storage.test/photo-1.jpg';

  @override
  Future<String> upload(Uint8List bytes) async {
    uploaded.add(bytes);
    return nextUrl;
  }

  @override
  Future<void> deleteByUrl(String url) async => deletedUrls.add(url);

  @override
  Future<void> deleteAll() async => deleteAllCalled = true;
}

Recipe recipeWith({String? photo, String? photoUrl, String id = 'r1'}) => Recipe(
      id: id,
      name: 'Necron Lord',
      photo: photo,
      photoUrl: photoUrl,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('photo source', () {
    test('a Storage URL counts as having a photo', () {
      expect(recipeWith(photoUrl: 'https://storage.test/a.jpg').hasPhoto, isTrue);
    });

    test('a legacy base64 photo still counts', () {
      final legacy = base64Encode(Uint8List.fromList([1, 2, 3]));
      expect(recipeWith(photo: legacy).hasPhoto, isTrue);
    });

    test('no photo at all', () {
      expect(recipeWith().hasPhoto, isFalse);
      expect(recipeWith(photoUrl: '', photo: '').hasPhoto, isFalse);
    });

    test('both fields survive serialization', () {
      final map = recipeWith(photo: 'AAA', photoUrl: 'https://x/y.jpg').toMap();
      expect(map['photo'], 'AAA');
      expect(map['photoUrl'], 'https://x/y.jpg');
    });

    test('clearing the photo clears both sources', () {
      final cleared = recipeWith(photo: 'AAA', photoUrl: 'https://x/y.jpg')
          .copyWith(clearPhoto: true);
      expect(cleared.hasPhoto, isFalse);
    });
  });

  group('deleting a recipe', () {
    test('also deletes its uploaded photo', () async {
      final photos = FakeRecipePhotoRepository();
      final repository = FakeRecipeRepository();
      final provider = RecipesProvider(
        repository: repository,
        photoRepository: photos,
      );
      addTearDown(provider.dispose);

      final id = await repository.create(recipeWith());
      await provider.delete(
        recipeWith(id: id, photoUrl: 'https://storage.test/gone.jpg'),
      );

      expect(photos.deletedUrls, ['https://storage.test/gone.jpg']);
    });

    test('a recipe without a photo deletes nothing from Storage', () async {
      final photos = FakeRecipePhotoRepository();
      final repository = FakeRecipeRepository();
      final provider = RecipesProvider(
        repository: repository,
        photoRepository: photos,
      );
      addTearDown(provider.dispose);

      final id = await repository.create(recipeWith());
      await provider.delete(recipeWith(id: id));

      expect(photos.deletedUrls, isEmpty);
    });

    test('a legacy base64 photo needs no Storage delete', () async {
      final photos = FakeRecipePhotoRepository();
      final repository = FakeRecipeRepository();
      final provider = RecipesProvider(
        repository: repository,
        photoRepository: photos,
      );
      addTearDown(provider.dispose);

      final id = await repository.create(recipeWith());
      await provider.delete(recipeWith(id: id, photo: 'AAA'));

      expect(
        photos.deletedUrls,
        isEmpty,
        reason: 'it never occupied a Storage object',
      );
    });
  });
}
