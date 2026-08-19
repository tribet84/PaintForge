/// Who may open the admin panel.
///
/// This client-side check only decides what the UI shows; the enforceable
/// gate is the matching `isPlatformAdmin()` allowlist in `firestore.rules`.
/// Keep BOTH lists in sync or the panel will render and then fail with
/// PERMISSION_DENIED (or worse, the rules would let a non-admin query
/// everyone's data).
const Set<String> kAdminEmails = {'admin@example.com'};

/// True when [email] belongs to a platform admin.
///
/// [emailVerified] must be required: anyone can register an email/password
/// account claiming an address they don't own, and only verification proves
/// it. Firestore rules apply the same `email_verified` condition.
bool isPlatformAdmin({required String? email, required bool emailVerified}) {
  if (email == null || !emailVerified) return false;
  return kAdminEmails.contains(email.toLowerCase());
}
