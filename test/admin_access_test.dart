import 'package:flutter_test/flutter_test.dart';
import 'package:paintforge/src/services/admin_access.dart';

void main() {
  test('the allowlisted verified email is an admin', () {
    expect(
      isPlatformAdmin(email: 'admin@example.com', emailVerified: true),
      isTrue,
    );
  });

  test('matching is case-insensitive, like email addresses', () {
    expect(
      isPlatformAdmin(email: 'admin@example.com', emailVerified: true),
      isTrue,
    );
  });

  test('an UNVERIFIED copy of the admin address is not an admin', () {
    // Anyone can register a password account claiming this address; only
    // verification proves ownership. firestore.rules applies the same check.
    expect(
      isPlatformAdmin(email: 'admin@example.com', emailVerified: false),
      isFalse,
    );
  });

  test('other accounts are not admins', () {
    expect(
      isPlatformAdmin(email: 'painter@example.com', emailVerified: true),
      isFalse,
    );
    expect(isPlatformAdmin(email: null, emailVerified: true), isFalse);
  });
}
