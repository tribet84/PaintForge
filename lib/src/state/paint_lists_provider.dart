import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/paint_list_repository.dart';
import '../models/paint_list.dart';

/// Holds the user's custom paint lists.
///
/// Readiness is deliberately NOT computed here: it depends on the inventory,
/// so it stays a pure function on [PaintList] that callers feed the current
/// inventory into. That keeps the two providers independent.
class PaintListsProvider extends ChangeNotifier {
  PaintListsProvider({required PaintListRepository repository})
      : _repository = repository {
    _subscription = _repository.watchLists().listen((lists) {
      _lists = lists;
      _loaded = true;
      notifyListeners();
    });
  }

  final PaintListRepository _repository;
  StreamSubscription<List<PaintList>>? _subscription;

  List<PaintList> _lists = const [];
  bool _loaded = false;

  bool get loaded => _loaded;

  List<PaintList> get lists => _lists;

  PaintList? byId(String listId) {
    for (final list in _lists) {
      if (list.id == listId) return list;
    }
    return null;
  }

  Future<String> create(String name) => _repository.create(name.trim());

  /// Creates a list already populated — used when generating one from a
  /// recipe, so the paints land in a single write instead of N updates.
  Future<String> createWithPaints(String name, List<String> paintIds) =>
      _repository.create(name.trim(), paintIds: paintIds);

  Future<void> rename(String listId, String name) =>
      _repository.rename(listId, name.trim());

  Future<void> delete(String listId) => _repository.delete(listId);

  /// Adds [paintId] to the list if it is not already there.
  Future<void> addPaint(String listId, String paintId) {
    final list = byId(listId);
    if (list == null || list.paintIds.contains(paintId)) {
      return Future.value();
    }
    return _repository.setPaints(listId, [...list.paintIds, paintId]);
  }

  Future<void> removePaint(String listId, String paintId) {
    final list = byId(listId);
    if (list == null || !list.paintIds.contains(paintId)) {
      return Future.value();
    }
    return _repository.setPaints(
      listId,
      list.paintIds.where((id) => id != paintId).toList(),
    );
  }

  /// Whether [paintId] belongs to [listId]. Used to render the toggles in the
  /// "add to list" sheet.
  bool contains(String listId, String paintId) =>
      byId(listId)?.paintIds.contains(paintId) ?? false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
