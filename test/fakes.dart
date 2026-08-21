import 'dart:async';

import 'package:paintforge/src/services/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paintforge/src/data/inventory_repository.dart';
import 'package:paintforge/src/data/paint_list_repository.dart';
import 'package:paintforge/src/data/published_recipe_repository.dart';
import 'package:paintforge/src/data/recipe_repository.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/paint_list.dart';
import 'package:paintforge/src/models/recipe.dart';

/// Device-local settings backed by mocked storage. The hint starts dismissed
/// by default so the many tests about catalogue behaviour are not asked to
/// dismiss a banner first; hint tests opt in explicitly.
Future<AppSettings> testAppSettings({bool paintCardHintDismissed = true}) {
  SharedPreferences.setMockInitialValues({
    if (paintCardHintDismissed) 'paintCardHintDismissed': true,
  });
  return AppSettings.load();
}

/// Replays current state to every new listener, the way a Firestore snapshot
/// stream does, so providers see data immediately after construction.
Stream<T> _replay<T>(
  StreamController<T> source,
  T Function() current,
) {
  final controller = StreamController<T>();
  controller.add(current());
  final subscription = source.stream.listen(controller.add);
  controller.onCancel = subscription.cancel;
  return controller.stream;
}

/// In-memory inventory so provider logic can be tested without Firestore.
class FakeInventoryRepository implements InventoryRepository {
  final _entries = <String, InventoryEntry>{};
  final _controller =
      StreamController<Map<String, InventoryEntry>>.broadcast();

  void _emit() => _controller.add(Map.of(_entries));

  @override
  Stream<Map<String, InventoryEntry>> watchEntries() =>
      _replay(_controller, () => Map.of(_entries));

  @override
  Future<void> setStatus(String paintId, PaintStatus status) async {
    _entries[paintId] = InventoryEntry(paintId: paintId, status: status);
    _emit();
  }

  @override
  Future<void> remove(String paintId) async {
    _entries.remove(paintId);
    _emit();
  }

  /// Counts how many times the repository was asked to write, so tests can
  /// prove a bulk action is ONE round trip rather than one per paint.
  int writeCalls = 0;

  @override
  Future<void> setStatusForAll(
    Iterable<String> paintIds,
    PaintStatus status,
  ) async {
    writeCalls++;
    for (final id in paintIds) {
      _entries[id] = InventoryEntry(paintId: id, status: status);
    }
    _emit();
  }

  @override
  Future<void> removeAll(Iterable<String> paintIds) async {
    writeCalls++;
    for (final id in paintIds) {
      _entries.remove(id);
    }
    _emit();
  }
}

/// In-memory custom paint lists.
class FakePaintListRepository implements PaintListRepository {
  final _lists = <PaintList>[];
  final _controller = StreamController<List<PaintList>>.broadcast();

  void _emit() => _controller.add(List.of(_lists));

  /// See [FakeRecipeRepository.watchCalls].
  int watchCalls = 0;

  @override
  Stream<List<PaintList>> watchLists() {
    watchCalls++;
    return _replay(_controller, () => List.of(_lists));
  }

  @override
  Future<String> create(String name, {List<String> paintIds = const []}) async {
    final id = 'list-${_lists.length}';
    _lists.add(
      PaintList(
        id: id,
        name: name,
        paintIds: paintIds,
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> rename(String listId, String name) async {
    final index = _lists.indexWhere((l) => l.id == listId);
    if (index == -1) return;
    _lists[index] = _lists[index].copyWith(name: name);
    _emit();
  }

  @override
  Future<void> setPaints(String listId, List<String> paintIds) async {
    final index = _lists.indexWhere((l) => l.id == listId);
    if (index == -1) return;
    _lists[index] = _lists[index].copyWith(paintIds: paintIds);
    _emit();
  }

  @override
  Future<void> delete(String listId) async {
    _lists.removeWhere((l) => l.id == listId);
    _emit();
  }
}

/// In-memory recipes, most recently created first.
class FakeRecipeRepository implements RecipeRepository {
  final _recipes = <Recipe>[];
  final _controller = StreamController<List<Recipe>>.broadcast();

  void _emit() => _controller.add(List.of(_recipes));

  /// How many times a subscription was opened — the thing that actually
  /// costs Firestore reads, so a test can prove a tab nobody opened is free.
  int watchCalls = 0;

  @override
  Stream<List<Recipe>> watchRecipes() {
    watchCalls++;
    return _replay(_controller, () => List.of(_recipes));
  }

  @override
  Future<String> create(Recipe recipe) async {
    final id = 'recipe-${_recipes.length}';
    _recipes.insert(
      0,
      Recipe(
        id: id,
        name: recipe.name,
        description: recipe.description,
        sections: recipe.sections,
        links: recipe.links,
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> update(Recipe recipe) async {
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    if (index == -1) return;
    _recipes[index] = recipe;
    _emit();
  }

  @override
  Future<void> delete(String recipeId) async {
    _recipes.removeWhere((r) => r.id == recipeId);
    _emit();
  }
}

/// In-memory public sharing layer, keyed by published id.
class FakePublishedRecipeRepository implements PublishedRecipeRepository {
  FakePublishedRecipeRepository({this.uid = 'owner'});

  final String uid;
  final _published = <String, PublishedRecipe>{};
  final _linkedIds = <String>{};
  final _linkedController = StreamController<List<String>>.broadcast();

  void _emitLinked() => _linkedController.add(_linkedIds.toList());

  /// Seeds a public recipe so tests can watch/link/unpublish it.
  void seed(PublishedRecipe published) => _published[published.id] = published;

  /// Simulates the author unsharing it: the doc disappears, the follower's
  /// own bookmark does not — that mismatch is exactly what leaves a dead
  /// linked entry in a subscriber's account.
  void unpublishFromAuthorSide(String publishedId) =>
      _published.remove(publishedId);

  @override
  Future<String> publish(Recipe recipe, {required String authorName}) async {
    final id = 'pub-${_published.length}';
    _published[id] = PublishedRecipe(
      id: id,
      ownerUid: uid,
      authorName: authorName,
      recipe: recipe,
    );
    return id;
  }

  @override
  Future<void> updatePublished(Recipe recipe, {required String authorName}) async {
    final id = recipe.publishedId;
    if (id == null) return;
    // A real Firestore .set() recreates a deleted doc under the same id —
    // exactly what a reshare after unpublish relies on.
    _published[id] = PublishedRecipe(
      id: id,
      ownerUid: uid,
      authorName: authorName,
      recipe: recipe,
    );
  }

  @override
  Future<void> unpublish(String publishedId) async {
    _published.remove(publishedId);
  }

  @override
  Stream<PublishedRecipe?> watchPublished(String publishedId) =>
      Stream.value(_published[publishedId]);

  @override
  Future<List<PublishedRecipe>> byAuthor(String ownerUid) async => [
        for (final p in _published.values)
          if (p.ownerUid == ownerUid) p,
      ]..sort((a, b) => b.recipe.updatedAt.compareTo(a.recipe.updatedAt));

  @override
  Stream<List<String>> watchLinkedIds() =>
      _replay(_linkedController, () => _linkedIds.toList());

  @override
  Future<void> link(String publishedId) async {
    _linkedIds.add(publishedId);
    _emitLinked();
  }

  @override
  Future<void> unlink(String publishedId) async {
    _linkedIds.remove(publishedId);
    _emitLinked();
  }

  @override
  Future<int> linkCount(String publishedId) async => 0;

  final _following = <String, Follow>{};
  final _followingController = StreamController<List<Follow>>.broadcast();
  final _followerCounts = <String, int>{};

  void _emitFollowing() =>
      _followingController.add(_following.values.toList());

  /// Test seam: pretend [authorUid] published/updated something at [when]
  /// by moving the follower's watermark BEFORE it.
  void backdateSeen(String authorUid, DateTime when) {
    final f = _following[authorUid];
    if (f == null) return;
    _following[authorUid] =
        (authorUid: f.authorUid, authorName: f.authorName, seenUpTo: when);
    _emitFollowing();
  }

  @override
  Stream<List<Follow>> watchFollowing() =>
      _replay(_followingController, () => _following.values.toList());

  @override
  Future<void> follow(String authorUid, String authorName) async {
    // Mirrors the Firestore contract: re-following is a no-op, never a
    // rewrite of the seenUpTo watermark.
    if (_following.containsKey(authorUid)) return;
    _following[authorUid] = (
      authorUid: authorUid,
      authorName: authorName,
      seenUpTo: DateTime.now(),
    );
    _followerCounts[authorUid] = (_followerCounts[authorUid] ?? 0) + 1;
    _emitFollowing();
  }

  @override
  Future<void> unfollow(String authorUid) async {
    if (_following.remove(authorUid) != null) {
      _followerCounts[authorUid] = (_followerCounts[authorUid] ?? 1) - 1;
    }
    _emitFollowing();
  }

  @override
  Future<int> followerCount(String authorUid) async =>
      _followerCounts[authorUid] ?? 0;

  @override
  Future<void> markAllSeen() async {
    final now = DateTime.now();
    for (final e in _following.entries.toList()) {
      _following[e.key] = (
        authorUid: e.value.authorUid,
        authorName: e.value.authorName,
        seenUpTo: now,
      );
    }
    _emitFollowing();
  }
}
