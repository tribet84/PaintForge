import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../build_info.dart';
import '../../data/catalog_repository.dart';
import '../../services/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/external_link.dart';
import '../../services/install_hint.dart';
import '../../services/share_links.dart';
import '../../widgets/account_avatar.dart';
import '../admin/admin_screen.dart';
import 'delete_account_flow.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _languageLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (context.watch<AppSettings>().localeOverride?.languageCode) {
      'en' => 'English',
      'es' => 'Español',
      // Language names are shown in their own language on purpose — someone
      // stuck in the wrong locale must be able to recognise the way out.
      _ => l10n.settingsLanguageSystem,
    };
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<AppSettings>();
    final current = settings.localeOverride?.languageCode;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.settingsLanguage),
        children: [
          for (final (code, label) in [
            (null, l10n.settingsLanguageSystem),
            ('en', 'English'),
            ('es', 'Español'),
          ])
            ListTile(
              title: Text(label),
              trailing: code == current
                  ? const Icon(Icons.check)
                  : null,
              // The sentinel keeps "system" distinguishable from "dismissed"
              // in the dialog's return value.
              onTap: () =>
                  Navigator.of(dialogContext).pop(code ?? 'system'),
            ),
        ],
      ),
    );
    if (choice == null) return;
    await settings.setLocaleOverride(
      choice == 'system' ? null : Locale(choice),
    );
  }

  Future<void> _showInstallInstructions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsInstallTitle),
        // Same copy as the one-time home banner: the tile is the permanent
        // way back to it after the banner was dismissed.
        content: Text(l10n.installHintBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _editDisplayName(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final controller =
        TextEditingController(text: auth.currentUser?.displayName ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDisplayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(helperText: l10n.settingsDisplayNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    await auth.setDisplayName(name);
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsDisplayNameSaved)),
    );
  }

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
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editDisplayName(context),
          ),
          const Divider(),
          // Cosmetic gate only — the enforceable one is the matching claim
          // check in firestore.rules. The claim rides in the ID token, so no
          // admin identity lives anywhere in this (public) repository.
          FutureBuilder<bool>(
            future: auth.hasAdminClaim(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.query_stats),
                title: Text(l10n.adminTitle),
                subtitle: Text(l10n.adminEntrySubtitle),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminScreen(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(_languageLabel(context)),
            onTap: () => _pickLanguage(context),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsCatalogTitle),
            subtitle: Text(l10n.settingsCatalogSubtitle(catalog.paints.length)),
          ),
          // Only in a browser tab: inside the installed app the instructions
          // would describe a journey already completed.
          if (kIsWeb && !isStandaloneDisplay())
            ListTile(
              leading: const Icon(Icons.install_mobile),
              title: Text(l10n.settingsInstallTitle),
              subtitle: Text(l10n.settingsInstallSubtitle),
              onTap: () => _showInstallInstructions(context),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            subtitle: const Text('1.0.0'),
            // The raw build stamp is a developer tool for proving a stale
            // cache, not something every user should parse. It stays one tap
            // away rather than one line down.
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('1.0.0 · $buildStamp')),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(l10n.settingsFeedback),
            subtitle: Text(l10n.settingsFeedbackSubtitle),
            trailing: const Icon(Icons.open_in_new, size: 18),
            // Straight into the mail client: feedback arrives while the
            // friction is still felt, not when it is remembered in a chat.
            onTap: () => openMailTo(kFeedbackEmail, subject: 'PintaMinis'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLegal),
            subtitle: Text(l10n.settingsLegalSubtitle),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalLink(kLegalUrl),
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
