import 'dart:async';

import 'package:paintforge/src/data/inventory_repository.dart';
import 'package:paintforge/src/data/paint_list_repository.dart';
import 'package:paintforge/src/data/recipe_repository.dart';
import 'package:paintforge/src/models/inventory_entry.dart';
import 'package:paintforge/src/models/paint_list.dart';
import 'package:paintforge/src/models/recipe.dart';

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

  @override
  Stream<List<PaintList>> watchLists() =>
      _replay(_controller, () => List.of(_lists));

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

  @override
  Stream<List<Recipe>> watchRecipes() =>
      _replay(_controller, () => List.of(_recipes));

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
