import 'package:cloud_firestore/cloud_firestore.dart';

/// Platform-wide totals shown on the admin panel.
class PlatformStats {
  const PlatformStats({
    required this.painters,
    required this.inventoryEntries,
    required this.paintLists,
    required this.recipes,
    required this.publishedRecipes,
    required this.recipeLinks,
  });

  /// Painters with a `users/{uid}` doc (created on first sign-in by the
  /// sample-recipe seeder).
  final int painters;

  /// Paints tracked across every inventory (owned + running low + to buy).
  final int inventoryEntries;

  final int paintLists;

  /// Private recipes across all accounts.
  final int recipes;

  final int publishedRecipes;

  /// Times a painter linked someone else's published recipe.
  final int recipeLinks;
}

/// Platform activity during one week, for the admin panel's weekly charts.
///
/// These are ACTIVITY counts, not creation counts: most documents only carry
/// an `updatedAt` (nothing stores a createdAt, and user docs have no date at
/// all), so "recipes worked on this week" is answerable and "recipes created
/// this week" is not. The one true creation metric is [newLinks] — link
/// markers are written once and never updated.
class WeeklyActivity {
  const WeeklyActivity({
    required this.weekStart,
    required this.publishedUpdates,
    required this.newLinks,
    required this.recipeUpdates,
    required this.inventoryUpdates,
  });

  /// Monday 00:00 local time.
  final DateTime weekStart;

  final int publishedUpdates;
  final int newLinks;
  final int recipeUpdates;
  final int inventoryUpdates;
}

/// A published recipe as listed on the admin panel.
class SharedRecipeSummary {
  const SharedRecipeSummary({
    required this.id,
    required this.name,
    required this.authorName,
    required this.updatedAt,
    required this.linkCount,
  });

  final String id;
  final String name;
  final String authorName;
  final DateTime? updatedAt;
  final int linkCount;
}

/// Read-only aggregation layer for the admin panel.
///
/// Everything here runs as Firestore `count()` aggregations — the server
/// returns a single number, no user documents ever reach the client — but it
/// still needs the admin allowlist in `firestore.rules`: the collection-group
/// counts touch every user's private subtree, which normal accounts are
/// denied.
abstract class AdminStatsRepository {
  Future<PlatformStats> loadStats();

  /// Most recently updated published recipes, with their link counts.
  Future<List<SharedRecipeSummary>> latestShared({int limit = 10});

  /// Per-week activity, oldest week first, ending with the current week.
  Future<List<WeeklyActivity>> weeklyActivity({int weeks = 8});
}

class FirestoreAdminStatsRepository implements AdminStatsRepository {
  FirestoreAdminStatsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<PlatformStats> loadStats() async {
    // Unfiltered collection-group counts on purpose: adding a `where` to a
    // collection group needs a collection-group index, which this project
    // does not manage (there is no firestore.indexes.json).
    final counts = await Future.wait([
      _count(_firestore.collection('users')),
      _count(_firestore.collectionGroup('inventory')),
      _count(_firestore.collectionGroup('paintLists')),
      _count(_firestore.collectionGroup('recipes')),
      _count(_firestore.collection('publishedRecipes')),
      // The only `links` subcollection lives under publishedRecipes, so the
      // group count equals the total number of recipe links.
      _count(_firestore.collectionGroup('links')),
    ]);
    return PlatformStats(
      painters: counts[0],
      inventoryEntries: counts[1],
      paintLists: counts[2],
      recipes: counts[3],
      publishedRecipes: counts[4],
      recipeLinks: counts[5],
    );
  }

  @override
  Future<List<WeeklyActivity>> weeklyActivity({int weeks = 8}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday =
        today.subtract(Duration(days: today.weekday - DateTime.monday));

    // The range filters on collection groups need the COLLECTION_GROUP
    // single-field indexes declared in firestore.indexes.json — without them
    // Firestore rejects the query outright.
    Future<int> inWeek(
      Query<Map<String, dynamic>> query,
      String field,
      DateTime start,
    ) {
      return _count(query
          .where(field, isGreaterThanOrEqualTo: start)
          .where(field, isLessThan: start.add(const Duration(days: 7))));
    }

    return Future.wait([
      for (var i = weeks - 1; i >= 0; i--)
        () async {
          final start = currentMonday.subtract(Duration(days: 7 * i));
          final counts = await Future.wait([
            inWeek(_firestore.collection('publishedRecipes'), 'updatedAt',
                start),
            inWeek(_firestore.collectionGroup('links'), 'linkedAt', start),
            inWeek(_firestore.collectionGroup('recipes'), 'updatedAt', start),
            inWeek(
                _firestore.collectionGroup('inventory'), 'updatedAt', start),
          ]);
          return WeeklyActivity(
            weekStart: start,
            publishedUpdates: counts[0],
            newLinks: counts[1],
            recipeUpdates: counts[2],
            inventoryUpdates: counts[3],
          );
        }(),
    ]);
  }

  @override
  Future<List<SharedRecipeSummary>> latestShared({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('publishedRecipes')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data();
      return SharedRecipeSummary(
        id: doc.id,
        name: data['name'] as String? ?? '',
        authorName: data['authorName'] as String? ?? '',
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        linkCount: await _count(doc.reference.collection('links')),
      );
    }));
  }
}
