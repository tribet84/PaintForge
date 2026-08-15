import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/catalog_repository.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthService>();
    final catalog = context.read<CatalogRepository>();
    final user = auth.currentUser;

    return SafeArea(
      child: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (user?.email ?? '?').substring(0, 1).toUpperCase(),
              ),
            ),
            title: Text(user?.displayName ?? user?.email ?? ''),
            subtitle: user?.displayName != null ? Text(user?.email ?? '') : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsCatalogTitle),
            subtitle: Text(l10n.settingsCatalogSubtitle(catalog.paints.length)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            subtitle: const Text('1.0.0'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.signOut,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => auth.signOut(),
          ),
        ],
      ),
    );
  }
}
