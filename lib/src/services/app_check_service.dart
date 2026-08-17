import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// reCAPTCHA Enterprise site key, empty when App Check is not configured.
///
/// Injected at build time (`--dart-define=RECAPTCHA_SITE_KEY=...`) rather
/// than hardcoded: a site key is bound to a specific set of domains, so a
/// fork or a local build should not inherit this project's key and silently
/// fail attestation.
const kRecaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Turns on Firebase App Check, which attests that requests really come from
/// this app before Firestore and Storage will answer them.
///
/// Worth having because security rules answer "may this SIGNED-IN USER read
/// this document", never "is this actually my app asking". A script holding
/// a valid account can otherwise walk the public collections as fast as it
/// likes. App Check closes that gap, and it is the only layer that can:
/// the Firebase SDKs talk to googleapis.com directly, so no CDN or WAF in
/// front of the site ever sees that traffic.
///
/// Failure is deliberately swallowed. Attestation is a hardening layer, and
/// a reCAPTCHA hiccup must not be the reason someone cannot open their own
/// paint list.
Future<void> initializeAppCheck() async {
  if (kRecaptchaSiteKey.isEmpty) return;

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(kRecaptchaSiteKey),
    );
  } catch (error) {
    debugPrint('App Check activation skipped: $error');
  }
}
