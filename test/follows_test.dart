import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/state/follows_provider.dart';

import 'fakes.dart';

/// The follow/news cycle, pinned end to end: following subscribes to the
/// FUTURE, publishing rings the bell, and marking seen clears it without
/// losing anything.
void main() {
  PublishedRecipe published(String id, String owner, String name, DateTime at) =>
      PublishedRecipe(
        id: id,
        ownerUid: owner,
        authorName: 'Ana',
        recipe: Recipe(id: id, name: name, updatedAt: at),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('following does NOT ring the bell for the back catalogue', () async {
    final repository = FakePublishedRecipeRepository()
      ..seed(published('p1', 'ana', 'Old One',
          DateTime.now().subtract(const Duration(days: 30))));
    final provider = FollowsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.follow('ana', 'Ana');
    await settle();

    expect(provider.isFollowing('ana'), isTrue);
    expect(provider.news, isEmpty,
        reason: 'a follow subscribes to future work, not to a pile of '
            'everything the author ever made');
  });

  test('publishing after the follow rings the bell, newest first', () async {
    final repository = FakePublishedRecipeRepository();
    final provider = FollowsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.follow('ana', 'Ana');
    await settle();

    repository
      ..seed(published('p1', 'ana', 'First',
          DateTime.now().subtract(const Duration(seconds: 40))))
      ..seed(published('p2', 'ana', 'Second',
          DateTime.now().subtract(const Duration(seconds: 20))));
    // The fake rewinds the follower's clock to simulate time passing.
    repository.backdateSeen(
        'ana', DateTime.now().subtract(const Duration(minutes: 5)));
    await settle();

    expect(provider.news.map((p) => p.recipe.name), ['Second', 'First']);
  });

  test('re-following never resets the seen watermark', () async {
    final repository = FakePublishedRecipeRepository();
    final provider = FollowsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.follow('ana', 'Ana');
    repository.seed(published('p1', 'ana', 'Unseen news',
        DateTime.now().subtract(const Duration(seconds: 20))));
    repository.backdateSeen(
        'ana', DateTime.now().subtract(const Duration(minutes: 5)));
    await settle();
    expect(provider.news, hasLength(1), reason: 'sanity: the bell is ringing');

    // A second follow — e.g. the nudge firing before the first snapshot
    // loads — must not stamp a fresh watermark over the unseen news.
    // Straight at the repository: the provider has its own isFollowing
    // guard, and this test is about the layer underneath it.
    await repository.follow('ana', 'Ana');
    await settle();

    expect(provider.news, hasLength(1));
  });

  test('marking seen clears the bell', () async {
    final repository = FakePublishedRecipeRepository();
    final provider = FollowsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.follow('ana', 'Ana');
    await settle();
    repository.seed(published('p1', 'ana', 'New',
        DateTime.now().subtract(const Duration(seconds: 20))));
    repository.backdateSeen(
        'ana', DateTime.now().subtract(const Duration(minutes: 5)));
    await settle();
    expect(provider.news, hasLength(1));

    await provider.markAllSeen();
    await settle();

    expect(provider.news, isEmpty);
  });

  test('unfollowing silences the author', () async {
    final repository = FakePublishedRecipeRepository();
    final provider = FollowsProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.follow('ana', 'Ana');
    await settle();
    await provider.unfollow('ana');
    await settle();

    repository.seed(published('p1', 'ana', 'Unheard',
        DateTime.now().subtract(const Duration(seconds: 20))));
    await settle();

    expect(provider.isFollowing('ana'), isFalse);
    expect(provider.news, isEmpty);
  });
}
