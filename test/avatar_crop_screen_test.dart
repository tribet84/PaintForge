import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paintforge/l10n/generated/app_localizations.dart';
import 'package:paintforge/src/features/settings/avatar_crop_screen.dart';

/// A tiny real PNG, because the crop widget actually decodes its input —
/// garbage bytes would test the error path instead of the screen.
Uint8List tinyPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));

void main() {
  testWidgets('the crop screen offers a square crop and a save action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: AvatarCropScreen(imageBytes: tinyPng()),
      ),
    );
    await tester.pump();

    final crop = tester.widget<Crop>(find.byType(Crop));
    expect(crop.aspectRatio, 1,
        reason: 'the avatar renders in a circle; the crop must stay square');
    expect(find.text('Save'), findsOneWidget);
  });
}
