import 'package:flutter/material.dart';

/// The signed-in user's profile picture.
///
/// Google accounts supply a photo; email/password accounts do not, so this
/// falls back to [fallback] — which is also what a broken or rate-limited
/// avatar URL lands on, so the surrounding control is never left blank.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.photoUrl,
    required this.fallback,
    this.size = 28,
  });

  final String? photoUrl;

  /// Shown when there is no photo, or loading it fails.
  final Widget fallback;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null) return fallback;
    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
