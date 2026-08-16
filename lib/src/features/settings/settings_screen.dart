import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../build_info.dart';
import '../../data/catalog_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/account_avatar.dart';
import 'delete_account_flow.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthService>();
    final catalog = context.read<CatalogRepository>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: SafeArea(
        child: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: AccountAvatar(
              photoUrl: auth.photoUrl,
              size: 40,
              // Password accounts have no picture, so they keep the initial.
              fallback: CircleAvatar(
                child: Text(
                  (user?.email ?? '?').substring(0, 1).toUpperCase(),
                ),
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
            // The build stamp is injected at build time. Without it there is
            // no way to tell a stale cached bundle from a fresh one, which
            // turns "I don't see the update" into pure guesswork.
            subtitle: const Text('1.0.0 · $buildStamp'),
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.settingsDangerZone,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.deleteAccountTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l10n.deleteAccountSubtitle),
            onTap: () => runDeleteAccountFlow(context),
          ),
        ],
        ),
      ),
    );
  }
}
