import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/published_recipe_repository.dart';

/// Who the user follows, and what those authors published since the user
/// last looked.
///
/// Pull, not push, on purpose: the app has no server code and this keeps it
/// that way. On each change to the follow list the provider asks every
/// followed author's page for recipes newer than that follow's watermark —
/// a handful of small queries for a handful of follows, paid only by users
/// who actually follow someone. Web push (permission prompts, tokens, FCM)
/// stays out until data shows people miss things without it.
class FollowsProvider extends ChangeNotifier {
  FollowsProvider({required PublishedRecipeRepository repository})
      : _repository = repository {
    _subscription = _repository.watchFollowing().listen(_onFollowing);
  }

  final PublishedRecipeRepository _repository;
  StreamSubscription<List<Follow>>? _subscription;

  List<Follow> _following = const [];
  List<Follow> get following => _following;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Recipes published or updated since each follow's watermark, newest
  /// first. This IS the bell.
  List<PublishedRecipe> _news = const [];
  List<PublishedRecipe> get news => _news;

  Future<void> _onFollowing(List<Follow> follows) async {
    _following = follows;
    _loaded = true;
    // Refresh eagerly: the follow list only changes on explicit user action
    // or at startup, so this is never a hot loop.
    final collected = <PublishedRecipe>[];
    for (final follow in follows) {
      final published = await _repository.byAuthor(follow.authorUid);
      collected.addAll(
        published.where((p) => p.recipe.updatedAt.isAfter(follow.seenUpTo)),
      );
    }
    collected.sort((a, b) => b.recipe.updatedAt.compareTo(a.recipe.updatedAt));
    _news = collected;
    notifyListeners();
  }

  /// No-op when already following: the repository write is an unconditional
  /// set, so repeating it would reset the follow's seenUpTo watermark and
  /// silently swallow that author's unseen news. Callers guard on
  /// [isFollowing] too, but this list starts empty until the first snapshot
  /// arrives — the one window where a guard upstream can be wrong.
  Future<void> follow(String authorUid, String authorName) async {
    if (isFollowing(authorUid)) return;
    await _repository.follow(authorUid, authorName);
  }

  Future<void> unfollow(String authorUid) => _repository.unfollow(authorUid);

  bool isFollowing(String authorUid) =>
      _following.any((f) => f.authorUid == authorUid);

  /// Clears the bell. The list already on screen stays readable — marking
  /// as seen must never yank the news out from under the reader.
  Future<void> markAllSeen() => _repository.markAllSeen();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
