import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthService>();
    await _run(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_registering) {
        await auth.registerWithEmail(email, password);
      } else {
        await auth.signInWithEmail(email, password);
      }
    });
  }

  Future<void> _submitGoogle() async {
    final auth = context.read<AuthService>();
    await _run(() => auth.signInWithGoogle());
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).authGenericError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(FirebaseAuthException e) {
    final l10n = AppLocalizations.of(context);
    return switch (e.code) {
      'invalid-email' => l10n.authInvalidEmail,
      'weak-password' => l10n.authWeakPassword,
      'email-already-in-use' => l10n.authEmailInUse,
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        l10n.authWrongCredentials,
      _ => l10n.authGenericError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(size: 88),
                  const SizedBox(height: 8),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    l10n.appTagline,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.fieldRequired
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _busy ? null : _submitEmail(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? l10n.fieldRequired
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submitEmail,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registering ? l10n.signUp : l10n.signIn),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                    child: Text(
                      _registering
                          ? l10n.haveAccountPrompt
                          : l10n.noAccountPrompt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.orDivider),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _submitGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(l10n.signInWithGoogle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
