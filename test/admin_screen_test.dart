import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/data/admin_stats_repository.dart';
import 'package:paintforge/src/features/admin/admin_screen.dart';

class FakeAdminStatsRepository implements AdminStatsRepository {
  FakeAdminStatsRepository({
    this.stats = const PlatformStats(
      painters: 42,
      inventoryEntries: 1280,
      paintLists: 77,
      recipes: 191,
      publishedRecipes: 23,
      recipeLinks: 65,
    ),
    this.shared = const [],
  });

  PlatformStats stats;
  List<SharedRecipeSummary> shared;

  /// While true every load throws, the way Firestore surfaces a
  /// PERMISSION_DENIED or a dropped connection.
  bool failLoads = false;
  int loadCalls = 0;

  @override
  Future<PlatformStats> loadStats() async {
    loadCalls++;
    if (failLoads) throw Exception('permission-denied');
    return stats;
  }

  @override
  Future<List<SharedRecipeSummary>> latestShared({int limit = 10}) async {
    if (failLoads) throw Exception('permission-denied');
    return shared;
  }
}

Future<void> pumpAdmin(
  WidgetTester tester,
  AdminStatsRepository repository,
) async {
  // Tall enough that the whole panel fits: a lazy ListView never builds
  // offscreen children, so anything below the default 600px fold would be
  // invisible to the finders.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: AdminScreen(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every platform total', (tester) async {
    await pumpAdmin(tester, FakeAdminStatsRepository());

    expect(find.text('Registered painters'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('1280'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('191'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
  });

  testWidgets('lists the latest shared recipes with their link counts',
      (tester) async {
    await pumpAdmin(
      tester,
      FakeAdminStatsRepository(
        shared: [
          SharedRecipeSummary(
            id: 'pub-1',
            name: 'Ultramarines armour',
            authorName: 'Roberto',
            updatedAt: DateTime(2026, 8, 1),
            linkCount: 5,
          ),
          SharedRecipeSummary(
            id: 'pub-2',
            name: 'Rusty blades',
            authorName: 'Ana',
            updatedAt: null,
            linkCount: 1,
          ),
        ],
      ),
    );

    expect(find.text('Ultramarines armour'), findsOneWidget);
    expect(find.text('5 links'), findsOneWidget);
    expect(find.text('Rusty blades'), findsOneWidget);
    // No date on the second one — the subtitle is just the author.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('1 link'), findsOneWidget);
  });

  testWidgets('says so when nothing has been shared yet', (tester) async {
    await pumpAdmin(tester, FakeAdminStatsRepository(shared: const []));
    expect(find.text('Nothing has been shared yet.'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state, and retry recovers',
      (tester) async {
    final repository = FakeAdminStatsRepository()..failLoads = true;
    await pumpAdmin(tester, repository);

    expect(find.text("Couldn't load statistics"), findsOneWidget);
    expect(find.text('Registered painters'), findsNothing);

    repository.failLoads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Registered painters'), findsOneWidget);
    expect(repository.loadCalls, 2);
  });
}
