import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/data/catalog_repository.dart';
import 'src/services/ads_service.dart';
import 'src/services/share_links.dart';

Future<void> main() async {
  // Before anything else: on web the engine rewrites the URL during its own
  // routing setup, so a shared-recipe link must be read while it is still
  // intact.
  PendingShareLink.capture();

  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    // Most likely `flutterfire configure` has not been run yet. The app
    // still boots and explains how to finish the setup.
    debugPrint('Firebase init failed: $error');
  }

  await AdsService.initialize();

  final catalog = await CatalogRepository.loadFromAssets();

  runApp(PaintForgeApp(catalog: catalog, firebaseReady: firebaseReady));
}
