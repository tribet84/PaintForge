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

  /// Deterministic ramp (0, 3, 6, …) so tests can assert exact bar values.
  @override
  Future<List<WeeklyActivity>> weeklyActivity({int weeks = 8}) async {
    if (failLoads) throw Exception('permission-denied');
    final monday = DateTime(2026, 8, 17);
    return [
      for (var i = 0; i < weeks; i++)
        WeeklyActivity(
          weekStart: monday.subtract(Duration(days: 7 * (weeks - 1 - i))),
          publishedUpdates: i,
          newLinks: i * 3,
          recipeUpdates: i * 2,
          inventoryUpdates: i * 5,
        ),
    ];
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

  testWidgets('the weekly tab draws one bar chart per metric', (tester) async {
    await pumpAdmin(tester, FakeAdminStatsRepository());

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    expect(find.text('Activity over the last 8 weeks'), findsOneWidget);
    expect(find.text('New recipe links'), findsOneWidget);
    expect(find.text('Shared recipes updated'), findsOneWidget);
    expect(find.text('Recipes worked on'), findsOneWidget);
    expect(find.text('Inventory updates'), findsOneWidget);
    // The last week of the ramp: links = 7*3, inventory = 7*5.
    expect(find.text('21'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
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
