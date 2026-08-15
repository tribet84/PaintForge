import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import 'data/catalog_repository.dart';
import 'data/inventory_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'services/auth_service.dart';
import 'state/inventory_provider.dart';
import 'theme.dart';

class PaintForgeApp extends StatelessWidget {
  const PaintForgeApp({
    super.key,
    required this.catalog,
    required this.firebaseReady,
  });

  final CatalogRepository catalog;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CatalogRepository>.value(value: catalog),
        if (firebaseReady)
          Provider<AuthService>(create: (_) => FirebaseAuthService()),
      ],
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: PaintForgeTheme.light(),
        darkTheme: PaintForgeTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: firebaseReady ? const _AuthGate() : const FirebaseSetupScreen(),
      ),
    );
  }
}

/// Shows the login screen or the app depending on the auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return ChangeNotifierProvider<InventoryProvider>(
          key: ValueKey(user.uid),
          create: (_) => InventoryProvider(
            repository: FirestoreInventoryRepository(uid: user.uid),
          ),
          child: const HomeScreen(),
        );
      },
    );
  }
}

/// Shown when the app is built without Firebase configuration.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.firebaseSetupTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.firebaseSetupBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
