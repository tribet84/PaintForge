import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/models/recipe.dart';
import 'package:paintforge/src/widgets/recipe_photo_viewer.dart';

/// A cover photo is someone's paint job, and the detail a painter actually
/// wants out of it — how a highlight was feathered, how thin a glaze went on
/// — is invisible at thumbnail size. Opening it full screen with zoom is the
/// point of storing it at all.
void main() {
  Recipe recipeWithPhoto() => Recipe(
        id: 'r1',
        name: 'Necron Lord',
        // A 1x1 transparent GIF: enough to exercise the viewer without
        // depending on the network.
        photo: 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        updatedAt: DateTime(2026, 1, 1),
      );

  Widget harness(Widget Function(BuildContext) onPressed) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(builder: (context) => onPressed(context)),
      );

  testWidgets('opens the photo full screen, zoomable', (tester) async {
    final recipe = recipeWithPhoto();

    await tester.pumpWidget(harness(
      (context) => Scaffold(
        body: TextButton(
          onPressed: () => showRecipePhoto(context, recipe),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byType(InteractiveViewer),
      findsOneWidget,
      reason: 'without zoom the full-screen view adds nothing a bigger '
          'thumbnail would not',
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.maxScale, greaterThan(1));
  });

  testWidgets('closes when tapping away from the photo', (tester) async {
    final recipe = recipeWithPhoto();

    await tester.pumpWidget(harness(
      (context) => Scaffold(
        body: TextButton(
          onPressed: () => showRecipePhoto(context, recipe),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a recipe with no photo opens nothing', (tester) async {
    final recipe = Recipe(
      id: 'r2',
      name: 'No photo',
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(harness(
      (context) => Scaffold(
        body: TextButton(
          onPressed: () => showRecipePhoto(context, recipe),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byType(InteractiveViewer),
      findsNothing,
      reason: 'a blank full-screen view is worse than not reacting at all',
    );
  });
}
