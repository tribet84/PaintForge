import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/models/paint_list.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/widgets/recipe_card.dart';

Recipe recipeWith({
  String? photoUrl,
  List<RecipeSection> sections = const [],
}) =>
    Recipe(
      id: 'r1',
      name: 'Necron Lord',
      photoUrl: photoUrl,
      sections: sections,
      updatedAt: DateTime(2026, 1, 1),
    );

Widget harness(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('a recipe without a photo renders the plain layout',
      (tester) async {
    await tester.pumpWidget(harness(RecipeCard(
      recipe: recipeWith(),
      origin: RecipeOrigin.ownPrivate,
      onTap: () {},
    )));

    expect(find.text('Necron Lord'), findsOneWidget);
    expect(find.descendant(of: find.byType(RecipeCard), matching: find.byIcon(Icons.palette_outlined)), findsNothing);
  });

  testWidgets('a recipe with a photo renders as a gallery overlay card',
      (tester) async {
    await tester.pumpWidget(harness(RecipeCard(
      recipe: recipeWith(
        photoUrl: 'https://storage.test/photo.jpg',
        sections: [
          RecipeSection(name: 'Armour', steps: const []),
        ],
      ),
      origin: RecipeOrigin.ownShared,
      onTap: () {},
      readiness: const PaintListReadiness(
        total: 3,
        inStock: 3,
        low: 0,
        missing: 0,
      ),
    )));

    expect(find.text('Necron Lord'), findsOneWidget);
    // The plain description/section-count block is replaced by overlay
    // chips built from the same paint/section counts.
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
  });

  testWidgets('tapping the card triggers onTap regardless of photo',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(RecipeCard(
      recipe: recipeWith(photoUrl: 'https://storage.test/photo.jpg'),
      origin: RecipeOrigin.linked,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
