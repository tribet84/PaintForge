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
