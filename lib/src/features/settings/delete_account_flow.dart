import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../data/account_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/brand_loader.dart';

/// Whether [input] confirms the delete-account prompt for [phrase].
///
/// Trimmed and case-insensitive so a stray space or the shift key does not
/// block someone who is already about to delete their account.
bool matchesDeleteConfirmation(String input, String phrase) {
  return input.trim().toLowerCase() == phrase.trim().toLowerCase();
}

/// Confirms, deletes every Firestore document owned by the signed-in user,
/// then deletes the Firebase Auth account itself.
///
/// Data is wiped BEFORE the auth account so the account still exists (and can
/// retry) if anything in between fails — deleting the auth account first
/// would invalidate the ID token and strand the Firestore data undeletable.
///
/// Re-authentication is NOT requested up front: the user is already signed
/// in, so asking them to sign in again reads as a bug. Firebase only demands
/// a recent sign-in for accounts whose session has aged, and it says so by
/// throwing `requires-recent-login` — that is the only case that prompts,
/// and the deletion then resumes by itself.
Future<void> runDeleteAccountFlow(BuildContext context) async {
  final auth = context.read<AuthService>();
  final accountRepository = context.read<AccountRepository>();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await _showConfirmDialog(context);
  if (confirmed != true) return;
  if (!context.mounted) return;

  await _performDeletion(context, auth, accountRepository, messenger);
}

Future<bool?> _showConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _ConfirmDeleteDialog(),
  );
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog();

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _controller = TextEditingController();
  var _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phrase = l10n.deleteAccountConfirmPhrase;

    return AlertDialog(
      title: Text(l10n.deleteAccountConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountConfirmBody),
          const SizedBox(height: 16),
          Text(
            l10n.deleteAccountConfirmInstruction(phrase),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.deleteAccountConfirmFieldLabel,
              hintText: phrase,
            ),
            onChanged: (value) => setState(
              () => _matches = matchesDeleteConfirmation(value, phrase),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: Text(l10n.deleteAccountButton),
        ),
      ],
    );
  }
}

/// Returns true once identity is confirmed, false if the user backs out.
///
/// Only reached when Firebase actually rejected the deletion with
/// `requires-recent-login`.
Future<bool> _reauthenticate(BuildContext context, AuthService auth) async {
  final providerIds = auth.providerIds;
  if (providerIds.contains('google.com')) {
    return _reauthenticateWithGoogle(context, auth);
  }
  if (providerIds.contains('password')) {
    return _reauthenticateWithPassword(context, auth);
  }
  // Unknown/unavailable provider info — nothing sensible to prompt with.
  return false;
}

Future<bool> _reauthenticateWithGoogle(
  BuildContext context,
  AuthService auth,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _GoogleReauthDialog(auth: auth),
  );
  return result ?? false;
}

class _GoogleReauthDialog extends StatefulWidget {
  const _GoogleReauthDialog({required this.auth});

  final AuthService auth;

  @override
  State<_GoogleReauthDialog> createState() => _GoogleReauthDialogState();
}

class _GoogleReauthDialogState extends State<_GoogleReauthDialog> {
  var _working = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.auth.reauthenticateWithGoogle();
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _working = false;
        _error = error.code == 'reauthentication-cancelled'
            ? l10n.deleteAccountReauthCancelled
            : l10n.deleteAccountError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteAccountReauthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountReauthBody),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton.icon(
          onPressed: _working ? null : _continue,
          icon: const Icon(Icons.g_mobiledata),
          label: Text(l10n.deleteAccountReauthWithGoogle),
        ),
      ],
    );
  }
}

Future<bool> _reauthenticateWithPassword(
  BuildContext context,
  AuthService auth,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _PasswordReauthDialog(auth: auth),
  );
  return result ?? false;
}

class _PasswordReauthDialog extends StatefulWidget {
  const _PasswordReauthDialog({required this.auth});

  final AuthService auth;

  @override
  State<_PasswordReauthDialog> createState() => _PasswordReauthDialogState();
}

class _PasswordReauthDialogState extends State<_PasswordReauthDialog> {
  final _controller = TextEditingController();
  var _working = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.auth.reauthenticateWithPassword(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _working = false;
        _error = error.code == 'wrong-password' || error.code == 'invalid-credential'
            ? l10n.deleteAccountReauthWrongPassword
            : l10n.deleteAccountError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteAccountReauthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountReauthBody),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.deleteAccountReauthPasswordLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _working ? null : _submit,
          child: Text(l10n.actionConfirm),
        ),
      ],
    );
  }
}

Future<void> _performDeletion(
  BuildContext context,
  AuthService auth,
  AccountRepository accountRepository,
  ScaffoldMessengerState messenger,
) async {
  final l10n = AppLocalizations.of(context);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // Deleting cascades across Firestore and Storage, so this is a
          // genuinely slow wait and shows immediately rather than after the
          // usual anti-flicker delay.
          child: BrandLoader(
            size: 64,
            label: l10n.deleteAccountDeleting,
            delay: Duration.zero,
          ),
        ),
      ),
    ),
  );

  try {
    // Order matters: the auth account must outlive the data wipe, since
    // deleting it first would invalidate the token these writes need.
    await accountRepository.deleteAllData();
    try {
      await auth.deleteAccount();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') rethrow;
      // Only NOW is a fresh sign-in genuinely required. Close the progress
      // dialog while the user deals with the prompt, then resume.
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      final reauthenticated = await _reauthenticate(context, auth);
      if (!reauthenticated) {
        // Data is already gone but the account survives; say nothing
        // reassuring we cannot back up — surface it as a failure so the user
        // can retry, which will simply delete the (now empty) account.
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.deleteAccountReauthCancelled)),
        );
        return;
      }
      await auth.deleteAccount();
      // The progress dialog was already popped above.
      messenger.clearSnackBars();
      return;
    }
    // Success is also followed by authStateChanges() emitting null, which
    // swaps the whole tree to LoginScreen — but that is a side effect of the
    // real AuthService, not something this flow should depend on to close its
    // own dialog. Always pop explicitly.
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  } catch (error) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountError)));
  }
}
